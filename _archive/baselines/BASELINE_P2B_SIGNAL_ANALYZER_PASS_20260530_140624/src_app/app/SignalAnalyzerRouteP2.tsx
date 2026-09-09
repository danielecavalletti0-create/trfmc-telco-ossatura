import { useEffect, useState } from 'react'
import { SignalAnalyzerDomainP2 } from '../domains/signal-analyzer/SignalAnalyzerDomainP2'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function SignalAnalyzerRouteP2() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#signal-analyzer') return null

  return <SignalAnalyzerDomainP2 />
}
