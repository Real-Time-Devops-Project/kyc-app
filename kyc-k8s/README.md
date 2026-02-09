# KYC - Kubernetes Configuration & Helm Charts

This repository manages the Kubernetes manifests and Helm charts for deploying the KYC application (frontend and microservices).

## Contents

- Helm Charts (often found in `charts/` or at root).
- Manifests (YAML files for `Deployment`, `Service`, `Ingress`, `ConfigMap`).

## Deployment

### Using kubectl

```bash
kubectl apply -f .
```

### Using Helm

To install/upgrade the entire KYC release:

```bash
helm upgrade --install kyc-release .
```

## Structure

Each service has its own dedicated directory for manifests.
- `frontend/`
- `ekyc-service/`
- `vkyc-service/`
