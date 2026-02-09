# eKYC Microservice

This repository constitutes the backend service for Electronic Know Your Customer (eKYC) functionality.

## Technologies

- Node.js (Runtime)
- Express (Web Framework)
- Jest (Testing)

## Prerequisites

- Node.js (v18+)
- MongoDB/PostgreSQL (as applicable)

## Getting Started

1.  Navigate to the directory:
    ```bash
    cd kyc-ekyc-service
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Run the service:
    ```bash
    npm start
    ```

## Development

To run with nodemon:
```bash
npm run dev
```

## Docker

Build the Docker image:
```bash
docker build -t kyc-ekyc-service:latest .
```

## CI/CD 

Includes `Jenkinsfile` for CI pipeline. Ensure SonarQube, Trivy, and related tools are configured on your Jenkins server.
