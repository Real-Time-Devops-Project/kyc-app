# vKYC Microservice

This repository handles Video Know Your Customer (vKYC) functionality, focusing on real-time verification sessions.

## Technologies

- Node.js (Runtime)
- Express
- WebRTC (potentially)
- Jest (Testing)

## Prerequisites

- Node.js (v18+)
- Database connection (PostgreSQL/MongoDB)

## Getting Started

1.  Navigate to the directory:
    ```bash
    cd kyc-vkyc-service
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Start the service:
    ```bash
    npm start
    ```

## Development

Run with hot reload:
```bash
npm run dev
```

## Docker

Build image:
```bash
docker build -t kyc-vkyc-service:latest .
```

## Deployment

Refer to `kyc-k8s` repository for deployment manifests or use the included `Jenkinsfile`.
