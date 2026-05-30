const DB_NAME = 'trfmc-offline-db'
const DB_VERSION = 1
const DOC_STORE = 'documents'
const MUTATION_STORE = 'mutations'

export type CRDTDocument = {
  id: string
  content: string
  metadata: Record<string, any>
  updatedAt: number
  version: number
  vectorClock: Record<string, number>
}

export type OfflineMutation = {
  id: string
  documentId: string
  type: string
  delta: any
  createdAt: number
  syncedAt?: number
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (!('indexedDB' in window)) {
      reject(new Error('IndexedDB not supported'))
      return
    }

    const request = window.indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains(DOC_STORE)) {
        db.createObjectStore(DOC_STORE, { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains(MUTATION_STORE)) {
        const store = db.createObjectStore(MUTATION_STORE, { keyPath: 'id' })
        store.createIndex('documentId', 'documentId', { unique: false })
        store.createIndex('syncedAt', 'syncedAt', { unique: false })
      }
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function withStore<T>(storeName: string, mode: IDBTransactionMode, callback: (store: IDBObjectStore) => IDBRequest | IDBRequest[] | PromiseLike<IDBRequest | IDBRequest[]>): Promise<T> {
  const db = await openDatabase()
  return new Promise<T>((resolve, reject) => {
    const tx = db.transaction(storeName, mode)
    const store = tx.objectStore(storeName)
    const request = callback(store)

    const requests = Array.isArray(request) ? request : [request]
    let completedCount = 0

    requests.forEach((req) => {
      req.onsuccess = () => {
        completedCount += 1
        if (completedCount === requests.length && !tx.error) {
          resolve(req.result as T)
        }
      }
      req.onerror = () => reject(req.error)
    })

    tx.oncomplete = () => {
      if (requests.length === 0) resolve(undefined as unknown as T)
    }
    tx.onabort = () => reject(tx.error)
  })
}

export const OfflineService = {
  async init() {
    await openDatabase()
    if (navigator.onLine) {
      this.flushMutationQueue().catch(() => {
        // swallow for initial sync failure, offline fallback is expected
      })
    }
  },

  async saveDocument(doc: CRDTDocument) {
    return withStore<void>(DOC_STORE, 'readwrite', (store) => store.put(doc))
  },

  async getDocument(id: string) {
    return withStore<CRDTDocument | undefined>(DOC_STORE, 'readonly', (store) => store.get(id))
  },

  async listDocuments() {
    return withStore<CRDTDocument[]>(DOC_STORE, 'readonly', (store) => store.getAll())
  },

  async deleteDocument(id: string) {
    return withStore<void>(DOC_STORE, 'readwrite', (store) => store.delete(id))
  },

  async enqueueMutation(mutation: OfflineMutation) {
    const queued = {
      ...mutation,
      createdAt: Date.now(),
      syncedAt: undefined
    }
    return withStore<void>(MUTATION_STORE, 'readwrite', (store) => store.put(queued))
  },

  async getPendingMutations(documentId?: string) {
    return withStore<OfflineMutation[]>(MUTATION_STORE, 'readonly', (store) => {
      if (documentId) {
        const idx = store.index('documentId')
        return idx.getAll(IDBKeyRange.only(documentId))
      }
      return store.getAll()
    })
  },

  async clearMutation(id: string) {
    return withStore<void>(MUTATION_STORE, 'readwrite', (store) => store.delete(id))
  },

  async flushMutationQueue(sendFn?: (mutation: OfflineMutation) => Promise<void>) {
    if (!sendFn) return
    const mutations = await this.getPendingMutations()
    for (const mutation of mutations) {
      try {
        await sendFn(mutation)
        mutation.syncedAt = Date.now()
        await withStore<void>(MUTATION_STORE, 'readwrite', (store) => store.put(mutation))
      } catch (error) {
        console.warn('[OfflineService] flush failed', error)
      }
    }
  },

  async canUseIndexedDB() {
    return 'indexedDB' in window
  },

  createDocumentSnapshot(id: string, content: string, metadata: Record<string, any> = {}) {
    return {
      id,
      content,
      metadata,
      updatedAt: Date.now(),
      version: 1,
      vectorClock: {}
    }
  },

  createMutation(documentId: string, type: string, delta: any) {
    return {
      id: `${documentId}-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      documentId,
      type,
      delta,
      createdAt: Date.now()
    }
  }
}
