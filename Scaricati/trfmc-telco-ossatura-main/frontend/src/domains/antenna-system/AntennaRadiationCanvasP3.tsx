import { useEffect, useRef } from 'react'

type AntennaRadiationCanvasP3Props = {
  widthHint?: number
  heightHint?: number
}

function degToRad(deg: number) {
  return (deg * Math.PI) / 180
}

function patternGain(angleDeg: number) {
  const main = Math.exp(-Math.pow(angleDeg / 34, 2))
  const sideA = 0.18 * Math.exp(-Math.pow((angleDeg - 72) / 18, 2))
  const sideB = 0.16 * Math.exp(-Math.pow((angleDeg + 72) / 18, 2))
  const rear = 0.08 * Math.exp(-Math.pow((Math.abs(angleDeg) - 180) / 32, 2))
  return Math.max(0.04, main + sideA + sideB + rear)
}

export function AntennaRadiationCanvasP3({ widthHint = 980, heightHint = 430 }: AntennaRadiationCanvasP3Props) {
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
    ctx.clearRect(0, 0, width, height)

    const bg = ctx.createLinearGradient(0, 0, width, height)
    bg.addColorStop(0, 'rgba(1, 14, 28, 1)')
    bg.addColorStop(0.58, 'rgba(0, 20, 28, 1)')
    bg.addColorStop(1, 'rgba(0, 5, 12, 1)')
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, width, height)

    const polarCx = width * 0.31
    const polarCy = height * 0.54
    const polarR = Math.min(width * 0.24, height * 0.39)

    ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
    ctx.lineWidth = 1

    for (let ring = 1; ring <= 5; ring += 1) {
      ctx.beginPath()
      ctx.arc(polarCx, polarCy, polarR * ring / 5, 0, Math.PI * 2)
      ctx.stroke()
    }

    for (let deg = 0; deg < 360; deg += 30) {
      const a = degToRad(deg - 90)
      ctx.beginPath()
      ctx.moveTo(polarCx, polarCy)
      ctx.lineTo(polarCx + Math.cos(a) * polarR, polarCy + Math.sin(a) * polarR)
      ctx.stroke()
    }

    ctx.beginPath()
    for (let deg = -180; deg <= 180; deg += 2) {
      const gain = patternGain(deg)
      const r = polarR * (0.16 + gain * 0.84)
      const a = degToRad(deg - 90)
      const x = polarCx + Math.sin(a) * r
      const y = polarCy - Math.cos(a) * r
      if (deg === -180) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()

    const patternFill = ctx.createRadialGradient(polarCx, polarCy, polarR * 0.1, polarCx, polarCy, polarR)
    patternFill.addColorStop(0, 'rgba(134, 239, 172, .50)')
    patternFill.addColorStop(0.62, 'rgba(103, 232, 249, .32)')
    patternFill.addColorStop(1, 'rgba(14, 165, 233, .10)')

    ctx.fillStyle = patternFill
    ctx.fill()
    ctx.strokeStyle = 'rgba(134, 239, 172, .95)'
    ctx.lineWidth = 2
    ctx.stroke()

    ctx.fillStyle = '#e8f7ff'
    ctx.font = '700 11px ui-monospace, SFMono-Regular, Menlo, monospace'
    ctx.fillText('AZIMUTH RADIATION PATTERN · 65° HPBW · 17.5 dBi', 18, 24)

    ctx.fillStyle = '#86efac'
    ctx.fillText('RET 4.0° · 8T8R · +45/-45 cross-polar sector model', 18, 44)

    const panelX = width * 0.62
    const panelY = height * 0.16
    const panelW = width * 0.18
    const panelH = height * 0.62

    ctx.fillStyle = 'rgba(2, 10, 20, .88)'
    ctx.fillRect(panelX, panelY, panelW, panelH)
    ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
    ctx.strokeRect(panelX, panelY, panelW, panelH)

    const elements = 8
    for (let i = 0; i < elements; i += 1) {
      const y = panelY + 22 + i * (panelH - 44) / (elements - 1)
      const grad = ctx.createLinearGradient(panelX, y, panelX + panelW, y)
      grad.addColorStop(0, 'rgba(103, 232, 249, .12)')
      grad.addColorStop(0.5, 'rgba(134, 239, 172, .70)')
      grad.addColorStop(1, 'rgba(103, 232, 249, .12)')
      ctx.fillStyle = grad
      ctx.fillRect(panelX + 16, y - 4, panelW - 32, 8)
    }

    ctx.fillStyle = '#67e8f9'
    ctx.fillText('ANTENNA PANEL', panelX + 16, panelY - 12)

    const mapX = width * 0.82
    const mapY = height * 0.18

    ctx.fillStyle = 'rgba(0, 0, 0, .32)'
    ctx.fillRect(mapX - 12, mapY - 26, width * 0.16, 178)
    ctx.strokeStyle = 'rgba(103, 232, 249, .32)'
    ctx.strokeRect(mapX - 12, mapY - 26, width * 0.16, 178)

    ctx.fillStyle = '#e8f7ff'
    ctx.fillText('RRU / RET / CPRI', mapX, mapY)

    const rows = [
      ['A1', 'CPRI0', '+45°'],
      ['A2', 'CPRI1', '-45°'],
      ['B1', 'CPRI2', '+45°'],
      ['B2', 'CPRI3', '-45°'],
    ]

    rows.forEach((row, idx) => {
      const y = mapY + 25 + idx * 30
      ctx.fillStyle = 'rgba(103, 232, 249, .10)'
      ctx.fillRect(mapX - 2, y - 14, width * 0.13, 22)
      ctx.strokeStyle = 'rgba(103, 232, 249, .18)'
      ctx.strokeRect(mapX - 2, y - 14, width * 0.13, 22)
      ctx.fillStyle = idx % 2 === 0 ? '#86efac' : '#67e8f9'
      ctx.fillText(`${row[0]} · ${row[1]} · ${row[2]}`, mapX + 6, y)
    })

    ctx.strokeStyle = 'rgba(251, 191, 36, .70)'
    ctx.lineWidth = 2
    ctx.setLineDash([7, 6])
    ctx.beginPath()
    ctx.moveTo(polarCx, polarCy)
    ctx.bezierCurveTo(width * 0.42, height * 0.20, width * 0.50, height * 0.18, panelX, panelY + panelH * 0.40)
    ctx.stroke()
    ctx.setLineDash([])

    ctx.fillStyle = 'rgba(0, 0, 0, .35)'
    ctx.fillRect(18, height - 70, 430, 52)
    ctx.strokeStyle = 'rgba(103, 232, 249, .42)'
    ctx.strokeRect(18, height - 70, 430, 52)
    ctx.fillStyle = '#67e8f9'
    ctx.fillText('P3B ANTENNA SYSTEM · React Canvas', 30, height - 49)
    ctx.fillStyle = '#86efac'
    ctx.fillText('Radiation pattern · RRU/RET/CPRI/AISG · MIMO port mapping', 30, height - 29)
  }, [widthHint, heightHint])

  return (
    <canvas
      ref={canvasRef}
      className="trfmc-p3-antenna-canvas"
      aria-label="Antenna System radiation pattern and port mapping canvas"
    />
  )
}
