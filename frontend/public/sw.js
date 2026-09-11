const CACHE_NAME = 'trfmc-offline-cache-v2'
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/styles.css'
]

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS_TO_CACHE)).then(() => self.skipWaiting())
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  )
})

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return

  const requestUrl = new URL(event.request.url)
  const isSameOrigin = requestUrl.origin === self.location.origin

  if (!isSameOrigin) return

  // Le chiamate API non devono MAI ricevere una pagina HTML come risposta
  // di fallback: un errore di rete deve fallire in modo esplicito (il
  // codice chiamante lo gestisce gia' con try/catch), non essere
  // mascherato da una pagina che il parsing JSON rifiuterebbe comunque,
  // in modo silenzioso e fuorviante (bug analogo a quello di API_BASE
  // gia' corretto lato frontend).
  if (requestUrl.pathname.startsWith('/api/')) {
    event.respondWith(fetch(event.request))
    return
  }

  const isStandaloneHtmlPage =
    requestUrl.pathname.endsWith('.html') && requestUrl.pathname !== '/index.html'

  if (isStandaloneHtmlPage) {
    // Le ~200 pagine HTML indipendenti del portale (frontend/public/*.html)
    // sono in sviluppo attivo: la rete va sempre preferita (contenuto
    // fresco), la cache serve SOLO come fallback esplicito quando la rete
    // non risponde - mai una sostituzione silenziosa con la shell
    // principale, che confonderebbe "pagina non raggiungibile in questo
    // momento" con "questa e' la pagina corretta".
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const copy = response.clone()
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy))
          return response
        })
        .catch(() => caches.match(event.request))
    )
    return
  }

  // Shell principale (index.html) e asset statici (JS/CSS/immagini):
  // cache-first resta valido, qui il fallback a index.html ha senso
  // (e' letteralmente la shell che sta gia' cercando di caricare).
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) return cachedResponse
      return fetch(event.request)
        .then((response) => {
          const copy = response.clone()
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy))
          return response
        })
        .catch(() => caches.match('/index.html'))
    })
  )
})

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting()
  }
})
