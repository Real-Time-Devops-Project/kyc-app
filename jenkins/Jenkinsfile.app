pipeline {
    agent any

    tools {
        // Use the parameterized tool name, defaulting to 'nodejs-22-6-0' if not set
        nodejs "${env.NODE_TOOL_NAME ?: 'nodejs-22-6-0'}"
    }

    environment {
        // --- CONFIGURATION VARIABLES (Override these in Jenkins Job) ---
        AWS_REGION          = "${env.AWS_REGION ?: 'us-east-1'}"
        ECR_REPO_NAME       = "${env.ECR_REPO_NAME ?: 'kyc-app'}"
        EKS_CLUSTER_NAME    = "${env.EKS_CLUSTER_NAME ?: 'kyc-cluster'}"
        SERVICE_NAME        = "${env.SERVICE_NAME ?: 'ekyc-service'}"
        SERVICE_DIR         = "${env.SERVICE_DIR ?: 'kyc-app/ekyc-service'}"
        HELM_CHART_DIR      = "${env.HELM_CHART_DIR ?: 'kyc-app/k8s'}"
        SONAR_PROJECT_KEY   = "${env.SONAR_PROJECT_KEY ?: 'kyc-app'}"
        APP_PORT            = "${env.APP_PORT ?: '3001'}"
        
        // --- INTERNAL VARIABLES ---
        AWS_ACCOUNT_ID      = credentials('aws-account-id')
        ECR_REPO_URI        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
        IMAGE_TAG           = "v-${BUILD_NUMBER}"
        SCANNER_HOME        = tool 'SonarQube Scanner'
    }

    stages {
        stage('Installing Dependencies') {
            options { timestamp() }
            steps {
                dir("${SERVICE_DIR}") {
                    sh 'npm install --no-audit'
                }
            }
        }

        stage('Dependency Scanning') {
            parallel {
                stage('NPM Dependency Audit') {
                    steps {
                        dir("${SERVICE_DIR}") {
                            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                sh 'npm audit --audit-level=critical'
                            }
                        }
                    }
                }

                stage('OWASP Dependency Check') {
                    steps {
                        dependencyCheck additionalArguments: "--scan ./${SERVICE_DIR} --format ALL --prettyPrint", odcInstallation: 'OWASP-Dependency-Check'
                        dependencyCheckPublisher failedTotalCritical: 1, pattern: 'dependency-check-report.xml', stopBuild: false
                    }
                }
            }
        }

        stage('Build & Unit Test') {
            steps {
                dir("${SERVICE_DIR}") {
                    sh 'npm test'
                }
            }
        }

        stage('Code Coverage') {
            steps {
                dir("${SERVICE_DIR}") {
                    catchError(buildResult: 'SUCCESS', message: 'Coverage failed', stageResult: 'UNSTABLE') {
                        sh 'npm test -- --coverage'
                    }
                }
            }
        }

        stage('SAST Analysis (SonarQube)') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${SCANNER_HOME}/bin/sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.sources=${SERVICE_DIR} \
                            -Dsonar.javascript.lcov.reportPaths=${SERVICE_DIR}/coverage/lcov.info
                        """
                    }
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Dockerfile Scan (Hadolint)') {
            steps {
                dir("${SERVICE_DIR}") {
                    sh 'docker run --rm -i hadolint/hadolint < Dockerfile | tee hadolint.log'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir("${SERVICE_DIR}") {
                    script {
                        dockerImage = docker.build("${ECR_REPO_URI}:${IMAGE_TAG}")
                    }
                }
            }
        }

        stage('Trivy Vulnerability Scanner') {
            steps {
                sh "trivy image ${ECR_REPO_URI}:${IMAGE_TAG} --severity LOW,MEDIUM,HIGH --exit-code 0 --quiet --format json -o trivy-image-MEDIUM-results.json"
                sh "trivy image ${ECR_REPO_URI}:${IMAGE_TAG} --severity CRITICAL --exit-code 1 --quiet --format json -o trivy-image-CRITICAL-results.json"
            }
            post {
                always {
                    script {
                        try {
                            sh 'trivy convert --format template --template "@/usr/local/share/trivy/templates/html.tpl" --output trivy-image-MEDIUM-results.html trivy-image-MEDIUM-results.json'
                            sh 'trivy convert --format template --template "@/usr/local/share/trivy/templates/html.tpl" --output trivy-image-CRITICAL-results.html trivy-image-CRITICAL-results.json'
                            sh 'trivy convert --format template --template "@/usr/local/share/trivy/templates/junit.tpl" --output trivy-image-MEDIUM-results.xml trivy-image-MEDIUM-results.json'
                            sh 'trivy convert --format template --template "@/usr/local/share/trivy/templates/junit.tpl" --output trivy-image-CRITICAL-results.xml trivy-image-CRITICAL-results.json'
                        } catch (Exception e) {
                            echo "Warning: Trivy conversion failed. Templates might be missing."
                        }
                    }
                }
            }
        }

        stage('Smoke Deploy & Test') {
            steps {
                script {
                    sh "docker run -d --name smoke-test-${BUILD_NUMBER} -p ${APP_PORT}:${APP_PORT} ${ECR_REPO_URI}:${IMAGE_TAG}"
                    sleep 10
                    try {
                        sh "curl --fail http://localhost:${APP_PORT}/health || exit 1"
                    } finally {
                        sh "docker stop smoke-test-${BUILD_NUMBER}"
                        sh "docker rm smoke-test-${BUILD_NUMBER}"
                    }
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    docker.withRegistry("https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com", "ecr:${AWS_REGION}:aws-credentials-id") {
                        dockerImage.push()
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials-id']]) {
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"
                    dir("${HELM_CHART_DIR}") {
                        sh "helm upgrade --install ${SERVICE_NAME} . --set image.repository=${ECR_REPO_URI} --set image.tag=${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('DAST Scan (OWASP ZAP)') {
            steps {
                script {
                    sh """
                        docker run --rm -v \$(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
                        -t http://${SERVICE_NAME}:80 -r zap_report.html || true
                    """
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: '**/test-results.xml'
            junit allowEmptyResults: true, testResults: '**/dependency-check-junit.xml'
            junit allowEmptyResults: true, testResults: '**/trivy-image-*.xml'

            publishHTML target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: "${SERVICE_DIR}/coverage/lcov-report",
                reportFiles: 'index.html',
                reportName: 'Code Coverage'
            ]

            publishHTML target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'dependency-check-report.html',
                reportName: 'Dependency Check'
            ]

            publishHTML target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'trivy-image-CRITICAL-results.html',
                reportName: 'Trivy Critical Vulnerabilities'
            ]
            
            publishHTML target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'zap_report.html',
                reportName: 'ZAP Security Report'
            ]
        }
    }
}
