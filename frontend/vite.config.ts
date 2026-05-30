import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const trfmcHealthPlugin = {
  name: 'trfmc-health-5173',
  configureServer(server) {
    server.middlewares.use((req, res, next) => {
      if (req.url === '/api/health') {
        res.statusCode = 200
        res.setHeader('Content-Type', 'application/json; charset=utf-8')
        res.end(JSON.stringify({
          ok: true,
          status: 'online',
          service: 'trfmc-portal',
          mode: 'vite-middleware-health',
          portal_port: 5173,
          portal_url: 'http://127.0.0.1:5173',
          architecture: 'single-port-portal',
          message: 'TRFMC portal is alive on port 5173'
        }, null, 2))
        return
      }
      next()
    })
  }
}

export default defineConfig({
  plugins: [react(), trfmcHealthPlugin],
  server: {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true
  },
  build: {
    target: 'es2020',
    outDir: 'dist',
    cssCodeSplit: true,
    sourcemap: false,
    chunkSizeWarningLimit: 600,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('/react/') || id.includes('/react-dom/')) return 'vendor-react'
            if (id.includes('/zustand/')) return 'vendor-zustand'
            if (id.includes('/lucide-react/')) return 'vendor-lucide'
            return 'vendor'
          }

          if (id.includes('/src/domains/') || id.includes('/src/rf_instruments/') || id.includes('/src/rf_scenarios/')) {
            return 'rf-domain'
          }
        }
      }
    }
  }
})
