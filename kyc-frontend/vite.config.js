import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    server: {
        host: true,
        port: 5173,
        proxy: {
            '/api/ekyc': {
                target: process.env.VITE_EKYC_URL || 'http://localhost:3001',
                changeOrigin: true,
            },
            '/api/vkyc': {
                target: process.env.VITE_VKYC_URL || 'http://localhost:3002',
                changeOrigin: true,
            }
        }
    }
})
