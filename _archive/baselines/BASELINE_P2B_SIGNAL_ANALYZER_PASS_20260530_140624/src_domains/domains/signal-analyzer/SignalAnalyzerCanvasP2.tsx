import { useEffect, useRef } from 'react'

type SignalAnalyzerCanvasP2Props = {
  widthHint?: number
  heightHint?: number
}

function gauss(x: number, mu: number, sigma: number, amp: number) {
  const z = (x - mu) / sigma
  return amp * Math.exp(-0.5 * z * z)
}

function spectrumValue(x: number, t: number) {
  const base = -106 + 2.4 * Math.sin(x * 22 + t * 0.08)
  const carrier = gauss(x, 0.50 + 0.015 * Math.sin(t * 0.03), 0.028, 46)
  const left = gauss(x, 0.36, 0.018, 22)
  const right = gauss(x, 0.66, 0.024, 18)
  const spur = gauss(x, 0.82, 0.009, 13)
  return base + carrier + left + right + spur
}

function normDb(dbm: number) {
  return Math.max(0, Math.min(1, (dbm + 112) / 62))
}

export function SignalAnalyzerCanvasP2({ widthHint = 980, heightHint = 430 }: SignalAnalyzerCanvasP2Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const pixelRatio = window.devicePixelRatio || 1
    const box = canvas.getBoundingClientRect()
    const width = Math.max(760, Math.floor(box.width || widthHint))
    const height = Math.max(360, Math.floor(box.height || heightHint))

    canvas.width = Math.floor(width * pixelRatio)
    canvas.height = Math.floor(height * pixelRatio)

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)

    const draw = (time: number) => {
      const t = time / 33.3
      ctx.clearRect(0, 0, width, height)

      const bg = ctx.createLinearGradient(0, 0, width, height)
      bg.addColorStop(0, 'rgba(1, 13, 25, 1)')
      bg.addColorStop(0.62, 'rgba(0, 18, 25, 1)')
      bg.addColorStop(1, 'rgba(0, 5, 12, 1)')
      ctx.fillStyle = bg
      ctx.fillRect(0, 0, width, height)

      const spectrumH = height * 0.42
      const waterfallY = spectrumH + 26
      const waterfallH = height * 0.30
      const iqX = width * 0.78
      const iqY = waterfallY + waterfallH + 22
      const iqR = Math.min(width * 0.15, height * 0.13)

      ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
      ctx.lineWidth = 1

      for (let gx = 0; gx <= 10; gx += 1) {
        const x = gx * width / 10
        ctx.beginPath()
        ctx.moveTo(x, 0)
        ctx.lineTo(x, spectrumH)
        ctx.stroke()
      }

      for (let gy = 0; gy <= 4; gy += 1) {
        const y = gy * spectrumH / 4
        ctx.beginPath()
        ctx.moveTo(0, y)
        ctx.lineTo(width, y)
        ctx.stroke()
      }

      ctx.beginPath()
      for (let i = 0; i < 512; i += 1) {
        const xNorm = i / 511
        const db = spectrumValue(xNorm, t)
        const y = spectrumH - normDb(db) * (spectrumH - 20) - 8
        const x = xNorm * width
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }

      ctx.strokeStyle = 'rgba(103, 232, 249, .95)'
      ctx.lineWidth = 2
      ctx.stroke()

      ctx.fillStyle = 'rgba(103, 232, 249, .10)'
      ctx.lineTo(width, spectrumH)
      ctx.lineTo(0, spectrumH)
      ctx.closePath()
      ctx.fill()

      ctx.fillStyle = '#e8f7ff'
      ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
      ctx.fillText('SPECTRUM · CENTER 2.440 GHz · SPAN 80 MHz · RBW 100 kHz', 18, 22)

      ctx.fillStyle = '#86efac'
      ctx.fillText('Peak -51.6 dBm · Noise floor -108 dBm · EVM 2.8%', 18, 42)

      for (let row = 0; row < 58; row += 1) {
        for (let col = 0; col < 160; col += 1) {
          const xNorm = col / 159
          const db = spectrumValue(xNorm, t - row * 1.6)
          const n = normDb(db)
          ctx.fillStyle = `rgba(${Math.floor(10 + n * 80)}, ${Math.floor(65 + n * 175)}, ${Math.floor(110 + n * 130)}, ${0.18 + n * 0.62})`
          ctx.fillRect(col * width / 160, waterfallY + row * waterfallH / 58, width / 160 + 1, waterfallH / 58 + 1)
        }
      }

      ctx.strokeStyle = 'rgba(103, 232, 249, .24)'
      ctx.strokeRect(0, waterfallY, width, waterfallH)
      ctx.fillStyle = '#67e8f9'
      ctx.fillText('WATERFALL · time-frequency persistence', 18, waterfallY + 18)

      const iqCenterX = iqX
      const iqCenterY = iqY + iqR * 0.52

      ctx.strokeStyle = 'rgba(103, 232, 249, .28)'
      ctx.beginPath()
      ctx.arc(iqCenterX, iqCenterY, iqR, 0, Math.PI * 2)
      ctx.stroke()

      ctx.beginPath()
      ctx.moveTo(iqCenterX - iqR, iqCenterY)
      ctx.lineTo(iqCenterX + iqR, iqCenterY)
      ctx.moveTo(iqCenterX, iqCenterY - iqR)
      ctx.lineTo(iqCenterX, iqCenterY + iqR)
      ctx.stroke()

      const qam = [-0.55, -0.18, 0.18, 0.55]
      ctx.fillStyle = 'rgba(134, 239, 172, .82)'
      for (const i of qam) {
        for (const q of qam) {
          const jitterI = Math.sin(t * 0.13 + i * 17 + q * 11) * 3.5
          const jitterQ = Math.cos(t * 0.11 + i * 13 - q * 19) * 3.5
          ctx.beginPath()
          ctx.arc(iqCenterX + i * iqR + jitterI, iqCenterY + q * iqR + jitterQ, 2.8, 0, Math.PI * 2)
          ctx.fill()
        }
      }

      ctx.fillStyle = '#e8f7ff'
      ctx.fillText('IQ CONSTELLATION · 16-QAM reference', iqCenterX - iqR, iqCenterY - iqR - 12)

      ctx.fillStyle = 'rgba(0, 0, 0, .35)'
      ctx.fillRect(16, height - 72, 360, 54)
      ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
      ctx.strokeRect(16, height - 72, 360, 54)
      ctx.fillStyle = '#67e8f9'
      ctx.fillText('P2B SIGNAL ANALYZER · React Canvas', 28, height - 50)
      ctx.fillStyle = '#86efac'
      ctx.fillText('FFT · spectrum · waterfall · IQ · EVM · OBW/ACLR registry', 28, height - 30)
    }

    draw(0)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p2-signal-canvas"
      aria-label="Signal Analyzer spectrum waterfall IQ canvas"
    />
  )
}
