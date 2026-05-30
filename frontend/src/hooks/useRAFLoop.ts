import { useEffect, useRef, DependencyList } from 'react'

/**
 * Custom hook for managing requestAnimationFrame loops with proper cleanup.
 * Ensures no memory leaks and prevents RAF re-initialization on unnecessary re-renders.
 *
 * @param callback - Function to call on each animation frame
 * @param deps - Dependency array to control when the loop restarts
 */
export function useRAFLoop(callback: (timestamp: number) => void, deps?: DependencyList) {
  const rafRef = useRef<number | null>(null)
  const callbackRef = useRef(callback)

  // Update callback ref on every render without restarting RAF
  useEffect(() => {
    callbackRef.current = callback
  }, [callback])

  useEffect(() => {
    let isActive = true
    let raf = 0

    const loop = (timestamp: number) => {
      if (!isActive) return
      callbackRef.current(timestamp)
      raf = requestAnimationFrame(loop)
    }

    raf = requestAnimationFrame(loop)
    rafRef.current = raf

    return () => {
      isActive = false
      if (raf !== null) {
        cancelAnimationFrame(raf)
      }
    }
  }, deps)

  // Optional: expose manual control if needed
  return {
    pause: () => {
      if (rafRef.current !== null) {
        cancelAnimationFrame(rafRef.current)
        rafRef.current = null
      }
    },
    resume: () => {
      if (rafRef.current === null) {
        rafRef.current = requestAnimationFrame((ts) => {
          callbackRef.current(ts)
        })
      }
    }
  }
}
