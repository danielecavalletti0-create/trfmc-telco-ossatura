import { useEffect, useRef } from 'react'

type RFPhysicsFieldCanvasP1Props = {
  widthHint?: number
  heightHint?: number
}

function dbmToNorm(dbm: number) {
  const clamped = Math.max(-110, Math.min(-45, dbm))
  return (clamped + 110) / 65
}

function fieldPower(x: number, y: number) {
  const txA = { x: 0.24, y: 0.34, p: -48 }
  const txB = { x: 0.72, y: 0.58, p: -53 }

  const distanceA = Math.hypot(x - txA.x, y - txA.y)
  const distanceB = Math.hypot(x - txB.x, y - txB.y)

  const ridge = Math.exp(-Math.pow((x - 0.52) * 4.2, 2)) * 8
  const obstruction = Math.exp(-Math.pow((x - 0.45), 2) / 0.012 - Math.pow((y - 0.58), 2) / 0.035) * 17

  const a = txA.p - 38 * Math.log10(1 + distanceA * 18)
  const b = txB.p - 36 * Math.log10(1 + distanceB * 18)

  return Math.max(a, b) + ridge - obstruction
}

function colorFor(norm: number) {
  const cyan = Math.floor(120 + norm * 120)
  const green = Math.floor(80 + norm * 160)
  const blue = Math.floor(120 + norm * 110)
  return `rgba(${Math.floor(norm * 60)}, ${green}, ${blue}, ${0.13 + norm * 0.42})`
}

export function RFPhysicsFieldCanvasP1({ widthHint = 920, heightHint = 320 }: RFPhysicsFieldCanvasP1Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const pixelRatio = window.devicePixelRatio || 1
    const box = canvas.getBoundingClientRect()
    const cssWidth = Math.max(620, Math.floor(box.width || widthHint))
    const cssHeight = Math.max(280, Math.floor(box.height || heightHint))

    canvas.width = Math.floor(cssWidth * pixelRatio)
    canvas.height = Math.floor(cssHeight * pixelRatio)

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)
    ctx.clearRect(0, 0, cssWidth, cssHeight)

    const background = ctx.createLinearGradient(0, 0, cssWidth, cssHeight)
    background.addColorStop(0, 'rgba(1, 12, 24, 1)')
    background.addColorStop(0.56, 'rgba(1, 25, 28, 1)')
    background.addColorStop(1, 'rgba(0, 5, 12, 1)')
    ctx.fillStyle = background
    ctx.fillRect(0, 0, cssWidth, cssHeight)

    const cols = 96
    const rows = 42
    const cellW = cssWidth / cols
    const cellH = cssHeight / rows

    for (let iy = 0; iy < rows; iy += 1) {
      for (let ix = 0; ix < cols; ix += 1) {
        const x = ix / (cols - 1)
        const y = iy / (rows - 1)
        const dbm = fieldPower(x, y)
        const norm = dbmToNorm(dbm)
        ctx.fillStyle = colorFor(norm)
        ctx.fillRect(ix * cellW, iy * cellH, Math.max(1, cellW - 1), Math.max(1, cellH - 1))
      }
    }

    ctx.strokeStyle = 'rgba(103, 232, 249, .22)'
    ctx.lineWidth = 1
    for (let gx = 0; gx <= 10; gx += 1) {
      const x = gx * cssWidth / 10
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, cssHeight)
      ctx.stroke()
    }
    for (let gy = 0; gy <= 6; gy += 1) {
      const y = gy * cssHeight / 6
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(cssWidth, y)
      ctx.stroke()
    }

    const drawTx = (xNorm: number, yNorm: number, label: string) => {
      const x = xNorm * cssWidth
      const y = yNorm * cssHeight

      const halo = ctx.createRadialGradient(x, y, 2, x, y, 72)
      halo.addColorStop(0, 'rgba(103, 232, 249, .65)')
      halo.addColorStop(1, 'rgba(103, 232, 249, 0)')
      ctx.fillStyle = halo
      ctx.beginPath()
      ctx.arc(x, y, 72, 0, Math.PI * 2)
      ctx.fill()

      ctx.fillStyle = '#67e8f9'
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, Math.PI * 2)
      ctx.fill()

      ctx.fillStyle = '#e8f7ff'
      ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
      ctx.fillText(label, x + 9, y - 8)
    }

    drawTx(0.24, 0.34, 'TX-A 2.440 GHz')
    drawTx(0.72, 0.58, 'TX-B sector')

    ctx.strokeStyle = 'rgba(251, 191, 36, .70)'
    ctx.lineWidth = 2
    ctx.setLineDash([7, 6])
    ctx.beginPath()
    ctx.moveTo(cssWidth * 0.17, cssHeight * 0.78)
    ctx.bezierCurveTo(cssWidth * 0.32, cssHeight * 0.58, cssWidth * 0.52, cssHeight * 0.45, cssWidth * 0.86, cssHeight * 0.24)
    ctx.stroke()
    ctx.setLineDash([])

    ctx.strokeStyle = 'rgba(248, 113, 113, .65)'
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.ellipse(cssWidth * 0.45, cssHeight * 0.58, 70, 34, -0.15, 0, Math.PI * 2)
    ctx.stroke()

    ctx.fillStyle = 'rgba(0, 0, 0, .38)'
    ctx.fillRect(14, 14, 238, 80)
    ctx.strokeStyle = 'rgba(103, 232, 249, .48)'
    ctx.strokeRect(14, 14, 238, 80)

    ctx.fillStyle = '#22d3ee'
    ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
    ctx.fillText('RF PHYSICS FIELD ENGINE P1', 24, 34)
    ctx.fillText('λ = 0.123 m · FSPL · RSRP/SINR', 24, 52)
    ctx.fillText('Canvas React · no public HTML runtime', 24, 70)

    ctx.fillStyle = '#86efac'
    ctx.fillText('source: v85b promoted model', 24, 88)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p1-rf-canvas"
      aria-label="RF Physics field model canvas"
    />
  )
}
