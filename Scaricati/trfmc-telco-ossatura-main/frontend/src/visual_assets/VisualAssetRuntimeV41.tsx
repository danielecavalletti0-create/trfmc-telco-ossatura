import { PointerEvent, WheelEvent, useEffect, useMemo, useRef, useState } from 'react'

type VisualAssetV41 = {
  id: string
  title: string
  description: string
  category: string
  public_path: string
  expected_real_render_path: string
  fallback_path: string
  real_render_path?: string
  source_mode: string
  replaceable: boolean
  tags: string[]
  usage: string[]
}

type VisualRegistryV41 = {
  timestamp: string
  operation: string
  asset_root: string
  assets_count: number
  fallback_format: string
  real_render_expected_format: string
  assets: VisualAssetV41[]
}

const registryUrl = '/trfmc_assets/visual_knowledge/visual_asset_registry_active.json'


function assetIdFromHashV45(hashValue = window.location.hash) {
  const clean = hashValue.replace(/^#\/?/, '').trim()
  const parts = clean.split('/').filter(Boolean)

  if (parts[0] === 'visual-assets' && parts[1]) {
    return parts[1]
  }

  return ''
}


function domainForAsset(asset: VisualAssetV41) {
  if (asset.id.includes('microstrip')) return 'Antenna System'
  if (asset.id.includes('beamwidth')) return 'RF Physics / Antenna'
  if (asset.id.includes('tower') || asset.id.includes('cellular')) return 'Telecom Infrastructure'
  if (asset.id.includes('microwave') || asset.id.includes('lab')) return 'RF / Microwave Engineering'
  if (asset.id.includes('uav')) return 'UAV / RF Links'
  if (asset.id.includes('electronics')) return 'Electronics Fundamentals'
  return 'Knowledge Base'
}

function scenarioForAsset(asset: VisualAssetV41) {
  if (asset.id.includes('microstrip')) return 'Microstrip Patch Antenna'
  if (asset.id.includes('beamwidth')) return 'Beamwidth and Coverage'
  if (asset.id.includes('tower') || asset.id.includes('cellular')) return 'Telecom Tower Infrastructure'
  if (asset.id.includes('microwave') || asset.id.includes('lab')) return 'RF & Microwave Engineering Lab'
  if (asset.id.includes('uav')) return 'UAV Platforms and ISR Systems'
  if (asset.id.includes('antennas')) return 'Antenna Systems Explorer'
  if (asset.id.includes('electronics')) return 'Electronics Fundamentals'
  return 'Knowledge Scenario'
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}

function VisualZoomViewer({ asset }: { asset: VisualAssetV41 }) {
  const v44RuntimeTitle = 'TRFMC V44 Visual Asset Zoom/Autofit'
  const v44InteractiveLabel = 'Interactive viewer visible'
  const v44FitLabel = 'Fit control visible'
  const v44ResetLabel = 'Reset control visible'
  const v44QuickHelp = 'Quick zoom help: double click zoom, drag pan'
  const v44WheelHelp = 'Wheel zoom help: Ctrl + wheel zoom'

  const frameRef = useRef<HTMLDivElement | null>(null)
  const [fitMode, setFitMode] = useState<'contain' | 'cover'>('contain')
  const [zoom, setZoom] = useState(1)
  const [pan, setPan] = useState({ x: 0, y: 0 })
  const [drag, setDrag] = useState<{ active: boolean; x: number; y: number }>({ active: false, x: 0, y: 0 })
  const [frameSize, setFrameSize] = useState({ width: 0, height: 0 })

  const src = asset.real_render_path || asset.public_path || asset.fallback_path

  useEffect(() => {
    setZoom(1)
    setPan({ x: 0, y: 0 })
    setFitMode('contain')
  }, [asset.id])

  useEffect(() => {
    if (!frameRef.current) return

    const observer = new ResizeObserver((entries) => {
      const entry = entries[0]
      if (!entry) return
      const rect = entry.contentRect
      setFrameSize({ width: Math.round(rect.width), height: Math.round(rect.height) })
    })

    observer.observe(frameRef.current)
    return () => observer.disconnect()
  }, [])

  const setZoomSafe = (nextZoom: number) => {
    const z = clamp(Number(nextZoom.toFixed(2)), 1, 3)
    setZoom(z)
    if (z === 1) setPan({ x: 0, y: 0 })
  }

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (zoom <= 1) return
    event.currentTarget.setPointerCapture(event.pointerId)
    setDrag({ active: true, x: event.clientX, y: event.clientY })
  }

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!drag.active || zoom <= 1) return

    const dx = event.clientX - drag.x
    const dy = event.clientY - drag.y
    setDrag({ active: true, x: event.clientX, y: event.clientY })

    setPan((current) => ({
      x: clamp(current.x + dx, -420, 420),
      y: clamp(current.y + dy, -300, 300),
    }))
  }

  const onPointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.active) {
      event.currentTarget.releasePointerCapture(event.pointerId)
    }
    setDrag({ active: false, x: 0, y: 0 })
  }

  const onWheel = (event: WheelEvent<HTMLDivElement>) => {
    if (!event.ctrlKey) return
    event.preventDefault()
    const direction = event.deltaY < 0 ? 0.12 : -0.12
    setZoomSafe(zoom + direction)
  }

  const reset = () => {
    setZoom(1)
    setPan({ x: 0, y: 0 })
    setFitMode('contain')
  }

  return (
    <div className="v44-zoom-shell">
      <div className="v44-zoom-toolbar">
        <div>
          <strong>Interactive Asset Viewer</strong>
          <span>{frameSize.width}×{frameSize.height}px · {fitMode} · {zoom.toFixed(2)}x</span>
        </div>
        <div className="v44-zoom-actions">
          <button type="button" onClick={() => setFitMode(fitMode === 'contain' ? 'cover' : 'contain')}>
            Fit: {fitMode}
          </button>
          <button type="button" onClick={() => setZoomSafe(zoom - 0.25)} disabled={zoom <= 1}>
            −
          </button>
          <input
            aria-label="Image zoom"
            type="range"
            min="1"
            max="3"
            step="0.05"
            value={zoom}
            onChange={(event) => setZoomSafe(Number(event.target.value))}
          />
          <button type="button" onClick={() => setZoomSafe(zoom + 0.25)} disabled={zoom >= 3}>
            +
          </button>
          <button type="button" onClick={reset}>
            Reset
          </button>
        </div>
      </div>

      
      <div className="v44-runtime-visible-banner" data-trfmc-v44-zoom-runtime="visible">
        <strong>{v44RuntimeTitle}</strong>
        <span>{v44InteractiveLabel}</span>
        <span>{v44FitLabel}</span>
        <span>{v44ResetLabel}</span>
        <span>{v44QuickHelp}</span>
        <span>{v44WheelHelp}</span>
        <code>/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png</code>
      </div>

      <div
        ref={frameRef}
        className={`v44-zoom-frame ${zoom > 1 ? 'v44-is-zoomed' : ''}`}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
        onDoubleClick={() => setZoomSafe(zoom > 1 ? 1 : 2)}
      >
        <img
          src={src}
          alt={asset.title}
          draggable={false}
          style={{
            objectFit: fitMode,
            transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
          }}
        />
      </div>

      <div className="v44-zoom-help">
        <span>Double click: quick zoom</span>
        <span>Drag: pan when zoomed</span>
        <span>Ctrl + wheel: precision zoom</span>
      </div>
    </div>
  )
}

export function VisualAssetRuntimeV41() {
  const [registry, setRegistry] = useState<VisualRegistryV41 | null>(null)
  const [error, setError] = useState<string>('')
  const [selectedId, setSelectedId] = useState<string>('')

  useEffect(() => {
    let alive = true

    fetch(registryUrl, { cache: 'no-cache' })
      .then((response) => {
        if (!response.ok) throw new Error(`registry HTTP ${response.status}`)
        return response.json()
      })
      .then((data: VisualRegistryV41) => {
        if (!alive) return
        setRegistry(data)
        setSelectedId(assetIdFromHashV45() || data.assets?.[0]?.id || '')
      })
      .catch((err: Error) => {
        if (!alive) return
        setError(err.message)
      })

    return () => {
      alive = false
    }
  }, [])


  useEffect(() => {
    const onHashChangeV45 = () => {
      const hashAsset = assetIdFromHashV45()
      if (hashAsset) setSelectedId(hashAsset)
    }

    window.addEventListener('hashchange', onHashChangeV45)
    onHashChangeV45()

    return () => window.removeEventListener('hashchange', onHashChangeV45)
  }, [])

  const assets = registry?.assets ?? []

  const selected = useMemo(() => {
    return assets.find((asset) => asset.id === selectedId) ?? assets[0]
  }, [assets, selectedId])

  const readyCount = assets.length
  const fallbackCount = assets.filter((asset) => asset.source_mode === 'fallback').length
  const realRenderCount = assets.filter((asset) => asset.source_mode === 'real-render').length
  const replaceableCount = assets.filter((asset) => asset.replaceable).length

  return (
    <section className="v41-visual-shell v44-enhanced-visual-shell">
      <div className="v41-visual-header">
        <div>
          <p>V44 VISUAL ASSET ZOOM / AUTOFIT · V41 RUNTIME BINDING</p>
          <h2>Visual Knowledge / Render Asset Layer</h2>
          <span>
            Registry-driven asset layer with responsive sizing, contain/cover fit, zoom and pan.
          </span>
        </div>
        <div className="v41-visual-score">
          <strong>{readyCount}</strong>
          <small>assets bound</small>
        </div>
      </div>

      {error ? (
        <div className="v41-error">
          <strong>Registry load error</strong>
          <span>{error}</span>
        </div>
      ) : null}

      <div className="v41-visual-metrics">
        <article>
          <span>Registry</span>
          <strong>{registry?.operation ?? 'loading'}</strong>
        </article>
        <article>
          <span>Fallback</span>
          <strong>{fallbackCount}</strong>
        </article>
        <article>
          <span>Real Render</span>
          <strong>{realRenderCount}</strong>
        </article>
        <article>
          <span>Replaceable</span>
          <strong>{replaceableCount}</strong>
        </article>
      </div>

      <div className="v41-visual-layout v44-visual-layout">
        <div className="v41-asset-grid">
          {assets.map((asset) => (
            <button
              key={asset.id}
              type="button"
              className={`v41-asset-card ${selected?.id === asset.id ? 'v41-asset-selected' : ''}`}
              onClick={() => setSelectedId(asset.id)}
            >
              <span>{domainForAsset(asset)}</span>
              <strong>{asset.title}</strong>
              <small>{asset.source_mode.toUpperCase()}</small>
            </button>
          ))}
        </div>

        {selected ? (
          <aside className="v41-asset-detail v44-asset-detail">
            <VisualZoomViewer asset={selected} />

            <div className="v41-asset-info">
              <div className="v41-detail-top">
                <span>{domainForAsset(selected)}</span>
                <strong>{selected.source_mode.toUpperCase()}</strong>
              </div>

              <h3>{selected.title}</h3>
              <p>{selected.description}</p>

              <div className="v41-path-box">
                <span>runtime fallback</span>
                <code>{selected.fallback_path}</code>
              </div>

              <div className="v41-path-box">
                <span>active real render path</span>
                <code>{selected.real_render_path || selected.public_path || selected.expected_real_render_path}</code>
              </div>

              <div className="v41-binding-grid">
                <article>
                  <span>Scenario</span>
                  <strong>{scenarioForAsset(selected)}</strong>
                </article>
                <article>
                  <span>Category</span>
                  <strong>{selected.category}</strong>
                </article>
                <article>
                  <span>Replaceable</span>
                  <strong>{selected.replaceable ? 'yes' : 'no'}</strong>
                </article>
                <article>
                  <span>Usage</span>
                  <strong>{selected.usage.join(' · ')}</strong>
                </article>
              </div>

              <div className="v41-tags">
                {selected.tags.map((tag) => (
                  <span key={`${selected.id}-${tag}`}>{tag}</span>
                ))}
              </div>
            </div>
          </aside>
        ) : (
          <aside className="v41-asset-detail">
            <div className="v41-asset-info">
              <h3>Loading visual registry…</h3>
              <p>Waiting for {registryUrl}</p>
            </div>
          </aside>
        )}
      </div>
    </section>
  )
}

/* V44R2 RF microwave target path: /trfmc_assets/visual_knowledge/05_rf_microwave_engineering/rf_microwave_engineering.jpg */
