import { useEffect, useState } from 'react'
import { RFPhysicsDomainP1 } from '../domains/rf-physics/RFPhysicsDomainP1'

function currentHash() {
  if (typeof window === 'undefined') return ''
  return window.location.hash || ''
}

export function RFPhysicsRouteP1() {
  const [hash, setHash] = useState(currentHash)

  useEffect(() => {
    const onHashChange = () => setHash(currentHash())
    window.addEventListener('hashchange', onHashChange)
    onHashChange()
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  if (hash !== '#rf-physics') return null

  return <RFPhysicsDomainP1 />
}
