import { useEffect, useState } from 'react'
import { AntennaSystemDomainP3 } from '../domains/antenna-system/AntennaSystemDomainP3'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function AntennaSystemRouteP3() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#antenna-system') return null

  return <AntennaSystemDomainP3 />
}
