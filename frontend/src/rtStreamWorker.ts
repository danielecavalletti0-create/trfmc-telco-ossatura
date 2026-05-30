export type RtWorkerCommand =
  | { type: 'connect'; url: string }
  | { type: 'disconnect' }
  | { type: 'send'; payload: any }
  | { type: 'ping' }

export type RtWorkerEvent =
  | { type: 'status'; status: 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR' | 'CLOSED'; reason?: string }
  | { type: 'message'; payload: any }
  | { type: 'error'; error: string }
  | { type: 'pong' }

const workerSelf = self as unknown as SharedWorkerGlobalScope
const ports: MessagePort[] = []
let ws: WebSocket | null = null
let currentUrl = ''
let reconnectTimer: number | null = null
let lastStatus: RtWorkerEvent = { type: 'status', status: 'DISCONNECTED' }

function broadcast(event: RtWorkerEvent) {
  for (const port of ports) {
    port.postMessage(event)
  }
}

function updateStatus(status: RtWorkerEvent['status'], reason?: string) {
  lastStatus = { type: 'status', status, reason }
  broadcast(lastStatus)
}

function openSocket(url: string) {
  if (ws) {
    if (currentUrl === url && ws.readyState === WebSocket.OPEN) {
      updateStatus('CONNECTED')
      return
    }
    ws.close()
    ws = null
  }

  currentUrl = url
  updateStatus('CONNECTING')

  try {
    ws = new WebSocket(url)

    ws.onopen = () => {
      updateStatus('CONNECTED')
      if (reconnectTimer) {
        clearTimeout(reconnectTimer)
        reconnectTimer = null
      }
    }

    ws.onmessage = (event) => {
      let payload = null
      try {
        payload = JSON.parse(event.data)
      } catch {
        payload = event.data
      }
      broadcast({ type: 'message', payload })
    }

    ws.onerror = (event) => {
      updateStatus('ERROR', 'WebSocket error')
      broadcast({ type: 'error', error: 'WebSocket error' })
      console.warn('[rtStreamWorker] WebSocket error', event)
    }

    ws.onclose = () => {
      updateStatus('CLOSED', 'WebSocket closed')
      if (ports.length > 0) {
        reconnectTimer = self.setTimeout(() => {
          if (currentUrl) openSocket(currentUrl)
        }, 3000)
      }
    }
  } catch (error) {
    updateStatus('ERROR', String(error))
  }
}

function closeSocket() {
  if (ws) {
    ws.close()
    ws = null
  }
  if (reconnectTimer) {
    clearTimeout(reconnectTimer)
    reconnectTimer = null
  }
  currentUrl = ''
  updateStatus('DISCONNECTED', 'Disconnected by client')
}

function handlePortMessage(port: MessagePort, message: RtWorkerCommand) {
  switch (message.type) {
    case 'connect':
      openSocket(message.url)
      break
    case 'disconnect':
      closeSocket()
      break
    case 'send':
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(message.payload))
      }
      break
    case 'ping':
      port.postMessage({ type: 'pong' })
      break
  }
}

workerSelf.onconnect = (event: MessageEvent) => {
  const port = event.ports[0]
  ports.push(port)
  port.start()
  port.postMessage(lastStatus)

  port.onmessage = (ev: MessageEvent<RtWorkerCommand>) => {
    handlePortMessage(port, ev.data)
  }

  port.onmessageerror = (ev) => {
    console.warn('[rtStreamWorker] port message error', ev)
  }

  port.onclose = () => {
    const index = ports.indexOf(port)
    if (index >= 0) ports.splice(index, 1)
    if (ports.length === 0) {
      closeSocket()
    }
  }
}
