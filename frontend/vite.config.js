import { defineConfig } from 'vite'

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
  plugins: [trfmcHealthPlugin],
  server: {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true
  }
})
