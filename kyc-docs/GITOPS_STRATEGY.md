# GitOps Implementation Strategy (Argo CD)

This document outlines the transition from CIOps (Jenkins Deploying) to **GitOps** (Argo CD Pulling).

## 1. Core Concept Change

| Feature | Old Strategy (CIOps) | New Strategy (GitOps) |
| :--- | :--- | :--- |
| **Source of Truth** | CI Server / Docker Registry | **Git Repository** |
| **Deployment Trigger** | Jenkins runs `helm upgrade` | **Argo CD** detects Git change |
| **Drift Detection** | None (Manual checks) | **Automatic** (Argo auto-corrects drift) |
| **Rollback** | Complex Jenkins job | `git revert` or Argo UI Click |

---

## 2. Updated Workflows

### Phase 1: Jenkins (CI only)
Jenkins NO LONGER touches the Kubernetes cluster directly.
1.  **Build**: Compiles code & runs tests.
2.  **Publish**: Pushes Docker Image to ECR.
3.  **Update Config**: Jenkins modifies `kyc-k8s/values-dev.yaml` (or `qa/prod`) with the new **Image Tag**.
4.  **Push Config**: Jenkins commits and pushes this YAML change back to Git.

### Phase 2: Argo CD (CD only)
Argo CD constantly polls the Git repository.
1.  **Detect**: Sees `values-dev.yaml` has a new image tag.
2.  **Sync**: Compares Git state vs K8s state.
3.  **Apply**: updates the Deployment in K8s to match Git.

---

## 3. Implementation Steps

### Step A: Install Argo CD
1.  Install Argo in your cluster:
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
2.  Access UI (Port Forward):
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

### Step B: Apply Application Manifests
We have created `kyc-argocd/applications.yaml`. Apply it to tell Argo about your apps:
```bash
kubectl apply -f kyc-argocd/applications.yaml
```

### Step C: Configure Jenkins
1.  **Git Credentials**: Jenkins needs a "Username/Password" credential (GitHub PAT) to push changes back to Git. ID: `git-credentials`.
2.  **Permissions**: Ensure the GitHub Token has `repo` scope.

---

## 4. Modified Jenkinsfiles
We have updated `Jenkinsfile.dev` as a reference.

**Old Code (Deleted):**
```groovy
sh "helm upgrade --install ..."
```

**New Code (Added):**
```groovy
sh "sed -i 's/tag: .*/tag: ${IMAGE_TAG}/' values-dev.yaml"
sh "git commit -m 'Update image tag'"
sh "git push"
```

## 5. Branching Strategy impact
*   **Dev Branch**: Observed by `kyc-app-dev` Argo Application.
*   **QA Branch**: Observed by `kyc-app-qa` Argo Application.
*   **Main Branch**: Observed by `kyc-app-prod` Argo Application.

Merging code from `dev` -> `qa` now implies merging the **Image Tag** changes in `values.yaml` as well.
