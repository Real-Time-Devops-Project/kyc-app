# KYC Frontend Application

This repository contains the frontend component of the KYC application, built using React.js.

## Technologies

- React.js
- Vite (Build Tool)
- TailwindCSS (Styling)

## Prerequisites

- Node.js (v18+)
- npm or yarn

## Getting Started

1.  Navigate to the repository:
    ```bash
    cd kyc-frontend
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Run the development server:
    ```bash
    npm run dev
    ```

## Building for Production

To create a production build:
```bash
npm run build
```

## Docker

Build the Docker image:
```bash
docker build -t kyc-frontend:latest .
```

## CI/CD

This repository includes a `Jenkinsfile` for CI/CD pipeline automation, including build, test, scan, and deployment stages.
ensure to configure your Jenkins environment with necessary credentials and tools.
