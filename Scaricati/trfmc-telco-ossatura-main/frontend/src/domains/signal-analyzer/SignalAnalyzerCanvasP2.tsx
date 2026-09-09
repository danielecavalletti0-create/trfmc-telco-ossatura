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
  const base = -108 + 2.3 * Math.sin(x * 18 + t * 0.092)
  const main = gauss(x, 0.50 + 0.015 * Math.sin(t * 0.036), 0.028, 44)
  const left = gauss(x, 0.33, 0.018, 20)
  const right = gauss(x, 0.67, 0.023, 16)
  const spur = gauss(x, 0.82, 0.008, 12)
  const haze = 2.8 * Math.exp(-Math.pow((x - 0.58) / 0.14, 2)) * Math.sin(t * 0.061)
  return base + main + left + right + spur + haze
}

function normDb(dbm: number) {
  return Math.max(0, Math.min(1, (dbm + 112) / 60))
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
      bg.addColorStop(0, 'rgba(3, 13, 28, 1)')
      bg.addColorStop(0.52, 'rgba(0, 16, 32, 1)')
      bg.addColorStop(1, 'rgba(0, 6, 14, 1)')
      ctx.fillStyle = bg
      ctx.fillRect(0, 0, width, height)

      const spectrumH = height * 0.42
      const waterfallY = spectrumH + 28
      const waterfallH = height * 0.30
      const iqX = width * 0.78
      const iqY = waterfallY + waterfallH + 28
      const iqR = Math.min(width * 0.145, height * 0.13)

      ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
      ctx.lineWidth = 1

      for (let gx = 0; gx <= 12; gx += 1) {
        const x = gx * width / 12
        ctx.beginPath()
        ctx.moveTo(x, 0)
        ctx.lineTo(x, spectrumH)
        ctx.stroke()
      }

      for (let gy = 0; gy <= 5; gy += 1) {
        const y = gy * spectrumH / 5
        ctx.beginPath()
        ctx.moveTo(0, y)
        ctx.lineTo(width, y)
        ctx.stroke()
      }

      const spectrumShade = ctx.createLinearGradient(0, 0, width, 0)
      spectrumShade.addColorStop(0, 'rgba(20, 120, 255, 0.08)')
      spectrumShade.addColorStop(0.5, 'rgba(0, 255, 236, 0.12)')
      spectrumShade.addColorStop(1, 'rgba(92, 138, 255, 0.06)')
      ctx.fillStyle = spectrumShade
      ctx.fillRect(0, 0, width, spectrumH)

      ctx.beginPath()
      for (let i = 0; i < 512; i += 1) {
        const xNorm = i / 511
        const db = spectrumValue(xNorm, t)
        const y = spectrumH - normDb(db) * (spectrumH - 28) - 16
        const x = xNorm * width
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }

      ctx.strokeStyle = 'rgba(0, 220, 255, .96)'
      ctx.lineWidth = 2.4
      ctx.shadowColor = 'rgba(0, 220, 255, 0.45)'
      ctx.shadowBlur = 18
      ctx.stroke()
      ctx.shadowBlur = 0

      ctx.fillStyle = 'rgba(0, 245, 255, 0.15)'
      ctx.lineTo(width, spectrumH)
      ctx.lineTo(0, spectrumH)
      ctx.closePath()
      ctx.fill()

      ctx.fillStyle = '#e8f7ff'
      ctx.font = '700 12px ui-monospace, SFMono-Regular, Menlo, monospace'
      ctx.fillText('SPECTRUM · CENTER 2.440 GHz · SPAN 80 MHz · RBW 100 kHz', 18, 24)

      ctx.fillStyle = '#86efac'
      ctx.fillText('Peak -52.1 dBm · Noise floor -108 dBm · EVM 2.4%', 18, 44)

      for (let row = 0; row < 58; row += 1) {
        const intensity = 1 - row / 62
        for (let col = 0; col < 160; col += 1) {
          const xNorm = col / 159
          const db = spectrumValue(xNorm, t - row * 1.4)
          const n = normDb(db)
          const blue = Math.floor(24 + n * 216)
          const green = Math.floor(76 + n * 180)
          const alpha = 0.12 + n * 0.56
          ctx.fillStyle = `rgba(0, ${Math.min(255, green)}, ${Math.min(255, blue)}, ${alpha * intensity})`
          ctx.fillRect(col * width / 160, waterfallY + row * waterfallH / 58, width / 160 + 1, waterfallH / 58 + 1)
        }
      }

      ctx.strokeStyle = 'rgba(103, 232, 249, .26)'
      ctx.lineWidth = 1.6
      ctx.strokeRect(0, waterfallY, width, waterfallH)

      ctx.fillStyle = '#67e8f9'
      ctx.fillText('WATERFALL · time-frequency persistence', 18, waterfallY + 20)

      ctx.fillStyle = '#10b981'
      ctx.fillText('burst clouds · spectral occupancy · latency aware', 18, waterfallY + 38)

      const iqCenterX = iqX
      const iqCenterY = iqY + iqR * 0.56

      const iqBg = ctx.createRadialGradient(iqCenterX, iqCenterY, 4, iqCenterX, iqCenterY, iqR * 1.05)
      iqBg.addColorStop(0, 'rgba(0, 142, 184, 0.08)')
      iqBg.addColorStop(1, 'rgba(0, 8, 16, 0.90)')
      ctx.fillStyle = iqBg
      ctx.fillRect(iqCenterX - iqR * 1.1, iqCenterY - iqR * 1.1, iqR * 2.2, iqR * 2.2)

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

      const qam = [-0.56, -0.18, 0.18, 0.56]
      for (const i of qam) {
        for (const q of qam) {
          const jitterI = Math.sin(t * 0.14 + i * 16 + q * 10) * 3.2
          const jitterQ = Math.cos(t * 0.12 + i * 11 - q * 18) * 3.2
          const px = iqCenterX + i * iqR + jitterI
          const py = iqCenterY + q * iqR + jitterQ

          ctx.fillStyle = 'rgba(134, 239, 172, .92)'
          ctx.shadowColor = 'rgba(134, 239, 172, .65)'
          ctx.shadowBlur = 12
          ctx.beginPath()
          ctx.arc(px, py, 3.4, 0, Math.PI * 2)
          ctx.fill()
          ctx.shadowBlur = 0
        }
      }

      ctx.fillStyle = '#e8f7ff'
      ctx.fillText('IQ CONSTELLATION · 16-QAM reference', iqCenterX - iqR, iqCenterY - iqR - 14)

      ctx.fillStyle = 'rgba(1, 9, 18, .42)'
      ctx.fillRect(18, height - 74, 374, 56)
      ctx.strokeStyle = 'rgba(103, 232, 249, .36)'
      ctx.strokeRect(18, height - 74, 374, 56)
      ctx.fillStyle = '#67e8f9'
      ctx.fillText('P2B SIGNAL ANALYZER · React Canvas', 30, height - 52)
      ctx.fillStyle = '#86efac'
      ctx.fillText('FFT · spectrum · waterfall · IQ · EVM · OBW/ACLR', 30, height - 30)
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
