# SECRETS MANAGEMENT & DYNAMIC CONFIGURATION GUIDE

This document outlines how to manage sensitive information (database credentials, API keys) dynamically without hardcoding them in the codebase.

## 1. Dynamic Configuration Strategy

**Goal:** No secrets in source code (`.tf`, `.js`, `Dockerfile`).
**Method:** All configuration is injected via **Environment Variables** at runtime.

### Where to Change Database Details
Instead of changing code, you change the **Environment Variables** passed to the deployment pipeline.

| Config Item | Variable Name | Default (Dev) | Production Source |
| :--- | :--- | :--- | :--- |
| **DB Name** | `TF_VAR_db_name` | `appdb` | Terraform Variable |
| **DB User** | `TF_VAR_db_username` | `adminuser` | Terraform Variable |
| **Postgres Password** | `TF_VAR_postgres_password` | *None* | **Secret Store** |
| **MongoDB Password** | `TF_VAR_docdb_password` | *None* | **Secret Store** |
| **API URL** | `VITE_API_URL` | `localhost` | Env Var (Build Time) |

---

## 2. Method A: AWS Secrets Manager (Recommended)

This method stores secrets in AWS and injects them into the build pipeline.

### Step 1: Create Secret in AWS
1.  Go to **AWS Console > Secrets Manager > Store a new secret**.
2.  Choose **Other type of secret**.
3.  Key/Value Pairs:
    *   `postgres_password`: `YourSecurePostgresPass!`
    *   `docdb_password`: `YourSecureMongoPass!`
    *   `db_username`: `adminuser`
4.  Secret Name: `kyc/prod/db-credentials`

### Step 2: Configure Jenkins to Read Secret
1.  Install **AWS Secrets Manager Credentials** plugin in Jenkins.
2.  In your `kyc-terraform/Jenkinsfile`, add a step to fetch the secret:

```groovy
stage('Fetch Secrets') {
    steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials-id']]) {
             script {
                 // Fetch JSON from Secrets Manager
                 def secret = sh(returnStdout: true, script: "aws secretsmanager get-secret-value --secret-id kyc/prod/db-credentials --query SecretString --output text").trim()
                 
                 // Parse JSON (requires jq installed on agent)
                 env.TF_VAR_postgres_password = sh(returnStdout: true, script: "echo '${secret}' | jq -r .postgres_password").trim()
                 env.TF_VAR_docdb_password = sh(returnStdout: true, script: "echo '${secret}' | jq -r .docdb_password").trim()
             }
        }
    }
}
```

### Step 3: Run Terraform
The env vars are now set. When `terraform apply` runs, it picks this up automatically.

---

## 3. Method B: HashiCorp Vault

This method uses a dedicated Vault server to manage secrets.

### Step 1: Write Secret to Vault
Run this on your Vault server or via CLI:
```bash
vault kv put secret/kyc/prod/db postgres_password="VaultPostgresPass!" docdb_password="VaultMongoPass!"
```

### Step 2: Configure Jenkins with Vault Plugin
1.  Install the **HashiCorp Vault** plugin in Jenkins.
2.  Configure the Vault URL and AppRole/Token credential in Jenkins System Configuration.

### Step 3: Update Jenkinsfile
Use the `withVault` wrapper to inject secrets as environment variables.

```groovy
stage('Deploy Infrastructure') {
    steps {
        withVault(configuration: [vaultUrl: 'https://vault.example.com', vaultCredentialId: 'vault-approle'], vaultSecrets: [
            [path: 'secret/kyc/prod/db', secretValues: [
                [envVar: 'TF_VAR_postgres_password', vaultKey: 'postgres_password'],
                [envVar: 'TF_VAR_docdb_password', vaultKey: 'docdb_password']
            ]]
        ]) {
            dir('environments/prod') {
                sh 'terraform apply -auto-approve'
            }
        }
    }
}
```

---

## 4. Code Modifications

All hardcoded values have been replaced with variables in the codebase.

**Terraform (`variables.tf`):**
```hcl
variable "postgres_password" {
  type      = string
  sensitive = true
}
variable "docdb_password" {
  type      = string
  sensitive = true
}
```

**Node.js (`.env`):**
The application reads from env vars. Ensure your deployment injects these:
`const pgPassword = process.env.PG_PASSWORD;`
`const mongoUri = process.env.MONGO_URI;` # Construct this string using the password

### Checklist for Production Deployment:
1.  [ ] Create `kyc/prod/db-credentials` in AWS Secrets Manager with BOTH passwords.
2.  [ ] Ensure Jenkins IAM Role has `secretsmanager:GetSecretValue`.
3.  [ ] Install `jq` on your Jenkins agent.
4.  [ ] Run the pipeline!
