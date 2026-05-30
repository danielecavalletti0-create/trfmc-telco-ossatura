export type PortalOSModuleStatus =
  | 'preview'
  | 'promoted'
  | 'reference'
  | 'reference-risk'
  | 'candidate'
  | 'candidate-visual'
  | 'candidate-operational'
  | 'legacy-leaf-review'
  | 'quarantine-review'

export type PortalOSModule = {
  id: string
  title: string
  category: string
  route: string
  status: PortalOSModuleStatus | string
  source: string
  description: string
  mode?: string
  priority?: string
  promotionScore?: number
  shellScore?: number
  canvas?: number
  iframe?: number
  script?: number
  risks?: string[]
  target?: string
}

export const portalOSPolicy = {
  singleSpa: true,
  singleReactRoot: true,
  v63AsVisualReference: true,
  legacyHtmlAsSource: true,
  noIframeAsArchitecture: true,
  promotionRequiresReactRewrite: true,
} as const

export const portalOSModules: PortalOSModule[] = 
[
  {
    "id": "home",
    "title": "Unified Portal OS Home",
    "category": "portal-os",
    "source": "frontend/src/portal-os/PortalOSRoot.tsx",
    "route": "#portal-os-preview",
    "status": "preview",
    "mode": "native-react",
    "priority": "P0",
    "promotionScore": 10000,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 0,
    "risks": [],
    "target": "core-root",
    "description": "native-react"
  },
  {
    "id": "rf-physics",
    "title": "RF Physics",
    "category": "rf-physics",
    "source": "frontend/src/domains/rf-physics/RFPhysicsDomainP1.tsx",
    "route": "#rf-physics",
    "status": "promoted",
    "mode": "native-react",
    "priority": "P1",
    "promotionScore": 9000,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 0,
    "risks": [],
    "target": "domain-runtime",
    "description": "native-react"
  },
  {
    "id": "signal-analyzer",
    "title": "Signal Analyzer",
    "category": "fft-dsp-signal",
    "source": "frontend/src/domains/signal-analyzer/SignalAnalyzerDomainP2.tsx",
    "route": "#signal-analyzer",
    "status": "promoted",
    "mode": "native-react",
    "priority": "P1",
    "promotionScore": 9000,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 0,
    "risks": [],
    "target": "domain-runtime",
    "description": "native-react"
  },
  {
    "id": "antenna-system",
    "title": "Antenna System",
    "category": "antenna-system",
    "source": "frontend/src/domains/antenna-system/AntennaSystemDomainP3.tsx",
    "route": "#antenna-system",
    "status": "promoted",
    "mode": "native-react",
    "priority": "P1",
    "promotionScore": 9000,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 0,
    "risks": [],
    "target": "domain-runtime",
    "description": "native-react"
  },
  {
    "id": "trfmc-rf-tm-war-room-v4",
    "title": "TRFMC RF/TM War Room V4",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_rf_tm_war_room_v4.html",
    "route": "#trfmc-rf-tm-war-room-v4",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 213,
    "shellScore": 2,
    "canvas": 8,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-pr200-field-monitoring-receiver-v1",
    "title": "TRFMC PR200 Style Field Monitoring Receiver V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_pr200_field_monitoring_receiver_v1.html",
    "route": "#trfmc-pr200-field-monitoring-receiver-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 197,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-antenna-system-explorer-v12-operativo",
    "title": "TRFMC Antenna System Explorer V1.2 Operativo",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v12_operativo.html",
    "route": "#trfmc-antenna-system-explorer-v12-operativo",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 197,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-antenna-system-explorer-v13-premium",
    "title": "TRFMC Antenna System Explorer V1.3 Premium",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v13_premium.html",
    "route": "#trfmc-antenna-system-explorer-v13-premium",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 197,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-rf-tm-signal-universe-v3",
    "title": "TRFMC RF/TM Signal Universe V3",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_tm_signal_universe_v3.html",
    "route": "#trfmc-rf-tm-signal-universe-v3",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 196,
    "shellScore": 4,
    "canvas": 8,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-instrument-os-alignment-v1",
    "title": "TRFMC Instrument OS Alignment V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_instrument_os_alignment_v1.html",
    "route": "#trfmc-instrument-os-alignment-v1",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 194,
    "shellScore": 2,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-measurement-chain-dsp-engine-v2",
    "title": "TRFMC Measurement Chain DSP Engine V2",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_measurement_chain_dsp_engine_v2.html",
    "route": "#trfmc-measurement-chain-dsp-engine-v2",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 193,
    "shellScore": 1,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-antenna-system-explorer-v1",
    "title": "TRFMC Antenna System Explorer V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v1.html",
    "route": "#trfmc-antenna-system-explorer-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 193,
    "shellScore": 1,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84m",
    "title": "TRFMC v0.84M · RF Sapienza Production Baseline",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84m.html",
    "route": "#rf-sapienza-console-v84m",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 189,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 10,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84k",
    "title": "TRFMC v0.84K · RF Sapienza Layer Director",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84k.html",
    "route": "#rf-sapienza-console-v84k",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 187,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84j",
    "title": "TRFMC v0.84J · RF 4D Measurement Theater",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84j.html",
    "route": "#rf-sapienza-console-v84j",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 186,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84g",
    "title": "TRFMC v0.84G · RF Topographic Instrument View",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84g.html",
    "route": "#rf-sapienza-console-v84g",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 185,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84i",
    "title": "TRFMC v0.84I · RF Vector Cartography Console",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84i.html",
    "route": "#rf-sapienza-console-v84i",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 185,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-enterprise-prime-portal-v1",
    "title": "TRFMC Enterprise Prime Portal V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_enterprise_prime_portal_v1.html",
    "route": "#trfmc-enterprise-prime-portal-v1",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 184,
    "shellScore": 3,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "rf-physics-sapienza-console-v86a",
    "title": "TRFMC v0.86A · RF Physics Sapienza Console",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_physics_sapienza_console_v86a.html",
    "route": "#rf-physics-sapienza-console-v86a",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84b",
    "title": "TRFMC v0.84B · RF Sapienza Console",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84b.html",
    "route": "#rf-sapienza-console-v84b",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84c",
    "title": "TRFMC v0.84C · RF Sapienza Console R2 R2",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84c.html",
    "route": "#rf-sapienza-console-v84c",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84d",
    "title": "TRFMC v0.84D · RF Sapienza Truth Palette R2",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84d.html",
    "route": "#rf-sapienza-console-v84d",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84e",
    "title": "TRFMC v0.84E · RF Sapienza Instrument Truth View",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84e.html",
    "route": "#rf-sapienza-console-v84e",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84f",
    "title": "TRFMC v0.84F · RF Instrument Dark Field Discipline",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84f.html",
    "route": "#rf-sapienza-console-v84f",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84h",
    "title": "TRFMC v0.84H · RF Atlas Instrument View",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_sapienza_console_v84h.html",
    "route": "#rf-sapienza-console-v84h",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 181,
    "shellScore": 0,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-signal-world-engine-v2",
    "title": "TRFMC Signal World Engine V2",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_signal_world_engine_v2.html",
    "route": "#trfmc-signal-world-engine-v2",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 176,
    "shellScore": 3,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-master-console-v4",
    "title": "TRFMC Master Console V4",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_master_console_v4.html",
    "route": "#trfmc-master-console-v4",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 174,
    "shellScore": 3,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "webgl-rf-tm-supreme-console-v84a",
    "title": "TRFMC v0.84A · RF T&M Supreme Console",
    "category": "fft-dsp-signal",
    "source": "frontend/public/webgl_rf_tm_supreme_console_v84a.html",
    "route": "#webgl-rf-tm-supreme-console-v84a",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 169,
    "shellScore": 0,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-performance-gpu-gate-v86b-r1",
    "title": "TRFMC v0.86B-R1 · Performance GPU Binding Gate R1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_performance_gpu_gate_v86b_r1.html",
    "route": "#trfmc-performance-gpu-gate-v86b-r1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 165,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-wifi-5-6-7-8-qam-engine-v1",
    "title": "TRFMC Wi-Fi 5/6/7/8 OFDM QAM Engine V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_wifi_5_6_7_8_qam_engine_v1.html",
    "route": "#trfmc-wifi-5-6-7-8-qam-engine-v1",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 162,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "webgl-rf-heatmap-engine-v69",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.69A · UE Mobility & Handover Dynamics",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v69.html",
    "route": "#webgl-rf-heatmap-engine-v69",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 159,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v66",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.66A · WebGL RF Heatmap Engine",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v66.html",
    "route": "#webgl-rf-heatmap-engine-v66",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 158,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v67",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.67A · Urban Shadowing & Clutter Engine",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v67.html",
    "route": "#webgl-rf-heatmap-engine-v67",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 158,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v68",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.68A · Seasonal Vegetation Clutter Engine",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v68.html",
    "route": "#webgl-rf-heatmap-engine-v68",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 158,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-sapienza-console-v84l",
    "title": "TRFMC v0.84L · RF Sapienza Director Cockpit",
    "category": "fft-dsp-signal",
    "source": "frontend/public/rf_sapienza_console_v84l.html",
    "route": "#rf-sapienza-console-v84l",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 158,
    "shellScore": 1,
    "canvas": 5,
    "iframe": 0,
    "script": 9,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-performance-gpu-gate-v86b",
    "title": "TRFMC v0.86B · Performance GPU Binding Gate",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_performance_gpu_gate_v86b.html",
    "route": "#trfmc-performance-gpu-gate-v86b",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 157,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v82-native-lab",
    "title": "TRFMC v0.82A · Native WebGL RF Vegetation Lab",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v82_native_lab.html",
    "route": "#webgl-rf-heatmap-engine-v82-native-lab",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 157,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-antenna-rru-ret-cpri-port-mapping-v1",
    "title": "Antenna / RRU / RET / CPRI Port Mapping Simulator",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v1.html",
    "route": "#trfmc-antenna-rru-ret-cpri-port-mapping-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 157,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-rf-spectrum-lab-v1",
    "title": "TRFMC RF Spectrum Lab V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_spectrum_lab_v1.html",
    "route": "#trfmc-rf-spectrum-lab-v1",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 154,
    "shellScore": 2,
    "canvas": 5,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-design-token-audit-v86f",
    "title": "TRFMC v0.86F · Design Token Audit",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_design_token_audit_v86f.html",
    "route": "#trfmc-design-token-audit-v86f",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 153,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-first-promotion-batch-v87a",
    "title": "TRFMC v0.87A · First Promotion Batch",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_first_promotion_batch_v87a.html",
    "route": "#trfmc-first-promotion-batch-v87a",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 153,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-mission-control-home-v87b",
    "title": "TRFMC v0.87B · Mission Control Home",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_mission_control_home_v87b.html",
    "route": "#trfmc-mission-control-home-v87b",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 153,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-portal-registry-v86c",
    "title": "TRFMC v0.86C · Portal Registry Navigation Spine",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_portal_registry_v86c.html",
    "route": "#trfmc-portal-registry-v86c",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 153,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v68-surgical-v81",
    "title": "TRFMC v0.81C-R2 · Seasonal Vegetation Clutter Engine · Cinematic Surgical Rebuild",
    "category": "5g-core-ran",
    "source": "frontend/public/webgl_rf_heatmap_engine_v68_surgical_v81.html",
    "route": "#webgl-rf-heatmap-engine-v68-surgical-v81",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 151,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-telco-knowledge-modules-v61",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.61A · RF/Telco Knowledge Modules",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_telco_knowledge_modules_v61.html",
    "route": "#rf-telco-knowledge-modules-v61",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 149,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-domain-registry-v1",
    "title": "TRFMC Domain Registry V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_domain_registry_v1.html",
    "route": "#trfmc-domain-registry-v1",
    "status": "reference",
    "mode": "core-shell-reference",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 145,
    "shellScore": 3,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-engine-promotion-board-v1",
    "title": "TRFMC Engine Promotion Board V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_engine_promotion_board_v1.html",
    "route": "#trfmc-engine-promotion-board-v1",
    "status": "reference",
    "mode": "core-shell-reference",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 141,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "core-shell-reference"
  },
  {
    "id": "rf-telco-knowledge-os-v60",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.60A · RF/Telco Knowledge Operating System",
    "category": "antenna-system",
    "source": "frontend/public/rf_telco_knowledge_os_v60.html",
    "route": "#rf-telco-knowledge-os-v60",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 140,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-5g-core-ran-identity-aka-engine-v1",
    "title": "TRFMC 5G Core/RAN Identity & AKA Engine",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_5g_core_ran_identity_aka_engine_v1.html",
    "route": "#trfmc-5g-core-ran-identity-aka-engine-v1",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 138,
    "shellScore": 4,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-measurement-chain-dsp-engine-v3",
    "title": "TRFMC Measurement Chain DSP Engine V3",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_measurement_chain_dsp_engine_v3.html",
    "route": "#trfmc-measurement-chain-dsp-engine-v3",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 138,
    "shellScore": 2,
    "canvas": 8,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-converged-rf-5g-noc-v1",
    "title": "TRFMC Converged RF + 5G NOC V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_converged_rf_5g_noc_v1.html",
    "route": "#trfmc-converged-rf-5g-noc-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 134,
    "shellScore": 3,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-expansion-hub-v1",
    "title": "TRFMC Expansion Hub V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_expansion_hub_v1.html",
    "route": "#trfmc-expansion-hub-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 134,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 1,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-safe-runtime-action-console-v1",
    "title": "TRFMC Safe Runtime Action Console V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_safe_runtime_action_console_v1.html",
    "route": "#trfmc-safe-runtime-action-console-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 133,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "field-engineering-mode-v64",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.65B · Field Telemetry on GPU Runtime",
    "category": "antenna-system",
    "source": "frontend/public/field_engineering_mode_v64.html",
    "route": "#field-engineering-mode-v64",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 132,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-unified-instrument-shell-lab-v2",
    "title": "TRFMC Unified Instrument Shell Lab V2",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_unified_instrument_shell_lab_v2.html",
    "route": "#trfmc-unified-instrument-shell-lab-v2",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 128,
    "shellScore": 4,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-antenna-system-explorer-v17-layout-lock-fullscreen",
    "title": "TRFMC Antenna System Explorer V1.7 Layout Lock Fullscreen",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v17_layout_lock_fullscreen.html",
    "route": "#trfmc-antenna-system-explorer-v17-layout-lock-fullscreen",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 128,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 12,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-stable-clean-recovery",
    "title": "TRFMC Antenna System Explorer STABLE CLEAN RECOVERY",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_STABLE_CLEAN_RECOVERY.html",
    "route": "#trfmc-antenna-system-explorer-stable-clean-recovery",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 126,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 10,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-v16r2-clean-dock-layout",
    "title": "TRFMC Antenna System Explorer V1.6R2 Clean Dock Layout",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v16r2_clean_dock_layout.html",
    "route": "#trfmc-antenna-system-explorer-v16r2-clean-dock-layout",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 126,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 10,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-home",
    "title": "TRFMC v0.87G · Public Operational Home",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_home.html",
    "route": "#trfmc-home",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 125,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-home-v87g",
    "title": "TRFMC v0.87G · Public Operational Home",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_home_v87g.html",
    "route": "#trfmc-home-v87g",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 125,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-unified-matrix-room-v3",
    "title": "TRFMC Unified Matrix Room V3",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_unified_matrix_room_v3.html",
    "route": "#trfmc-unified-matrix-room-v3",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 124,
    "shellScore": 3,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-v15-instrument-center",
    "title": "TRFMC Antenna System Explorer V1.5 Instrument Center",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v15_instrument_center.html",
    "route": "#trfmc-antenna-system-explorer-v15-instrument-center",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 124,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 8,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-v16-metrology-premium",
    "title": "TRFMC Antenna System Explorer V1.6 Metrology Premium",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v16_metrology_premium.html",
    "route": "#trfmc-antenna-system-explorer-v16-metrology-premium",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 124,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 8,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-v16r1-visible-antenna",
    "title": "TRFMC Antenna System Explorer V1.6R1 Metrology Premium Visible Antenna",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v16r1_visible_antenna.html",
    "route": "#trfmc-antenna-system-explorer-v16r1-visible-antenna",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 124,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 8,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "webgl-rf-physics-engine-v85d-runtime-identity-lock",
    "title": "TRFMC v0.85D · Sapienza Physics Baseline + RSRP/SINR Profile",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v85d_runtime_identity_lock.html",
    "route": "#webgl-rf-physics-engine-v85d-runtime-identity-lock",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 123,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 12,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v85e-viewport-discipline",
    "title": "TRFMC v0.85E · Sapienza Physics Baseline + RSRP/SINR Profile",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v85e_viewport_discipline.html",
    "route": "#webgl-rf-physics-engine-v85e-viewport-discipline",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 123,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 12,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-unified-evidence-supervisor-v4",
    "title": "TRFMC Unified Evidence Supervisor V4",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_unified_evidence_supervisor_v4.html",
    "route": "#trfmc-unified-evidence-supervisor-v4",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 123,
    "shellScore": 3,
    "canvas": 2,
    "iframe": 0,
    "script": 5,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-system-explorer-v14-instrument-grade",
    "title": "TRFMC Antenna System Explorer V1.4 Instrument Grade",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_system_explorer_v14_instrument_grade.html",
    "route": "#trfmc-antenna-system-explorer-v14-instrument-grade",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 123,
    "shellScore": 2,
    "canvas": 6,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-rf-physics-theory-atlas-v2",
    "title": "TRFMC RF Physics Theory Atlas V2",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_physics_theory_atlas_v2.html",
    "route": "#trfmc-rf-physics-theory-atlas-v2",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 123,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v85c-sapienza-identity",
    "title": "TRFMC v0.85C · Sapienza Physics Baseline + RSRP/SINR Profile",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v85c_sapienza_identity.html",
    "route": "#webgl-rf-physics-engine-v85c-sapienza-identity",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 122,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 11,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v85b-sapienza-baseline",
    "title": "TRFMC v0.85B · Sapienza Physics Baseline + RSRP/SINR Profile",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v85b_sapienza_baseline.html",
    "route": "#webgl-rf-physics-engine-v85b-sapienza-baseline",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 121,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 10,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-propagation-sandbox-v62",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.62B · RF Propagation Sandbox Visual Upgrade",
    "category": "antenna-system",
    "source": "frontend/public/rf_propagation_sandbox_v62.html",
    "route": "#rf-propagation-sandbox-v62",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 121,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83f",
    "title": "TRFMC v0.83F · Dual Instrument View + RSRP/SINR Profile",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83f.html",
    "route": "#webgl-rf-physics-engine-v83f",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 120,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 9,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83e",
    "title": "TRFMC v0.83E · Instrument Readability + Vector Governance",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83e.html",
    "route": "#webgl-rf-physics-engine-v83e",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 119,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v82c-r2-mission-replay",
    "title": "TRFMC v0.82C-R2 · Native WebGL Mission Replay Layout Fix",
    "category": "antenna-system",
    "source": "frontend/public/webgl_rf_heatmap_engine_v82c_r2_mission_replay.html",
    "route": "#webgl-rf-heatmap-engine-v82c-r2-mission-replay",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 119,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 8,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83d",
    "title": "TRFMC v0.83D · Instrument Layout + Link Budget Inspector",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83d.html",
    "route": "#webgl-rf-physics-engine-v83d",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 118,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v82c-mission-replay",
    "title": "TRFMC v0.82C · Native WebGL Mission Replay",
    "category": "antenna-system",
    "source": "frontend/public/webgl_rf_heatmap_engine_v82c_mission_replay.html",
    "route": "#webgl-rf-heatmap-engine-v82c-mission-replay",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 118,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83",
    "title": "TRFMC v0.83A · RF Physics Calibrated 4D Engine",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83.html",
    "route": "#webgl-rf-physics-engine-v83",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 117,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83b",
    "title": "TRFMC v0.83B · RF Precision Scale + Probe Diagnostics",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83b.html",
    "route": "#webgl-rf-physics-engine-v83b",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 117,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-physics-engine-v83c",
    "title": "TRFMC v0.83C · RF Sanity Calibration + SINR-Aware Coverage",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/webgl_rf_physics_engine_v83c.html",
    "route": "#webgl-rf-physics-engine-v83c",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 117,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "webgl-rf-heatmap-engine-v82b-native-lab",
    "title": "TRFMC v0.82B · Native WebGL RF Field Refinement",
    "category": "antenna-system",
    "source": "frontend/public/webgl_rf_heatmap_engine_v82b_native_lab.html",
    "route": "#webgl-rf-heatmap-engine-v82b-native-lab",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 117,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-core-network-live-ops-bridge-v1",
    "title": "TRFMC 5G Core Network Live Ops Bridge",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_core_network_live_ops_bridge_v1.html",
    "route": "#trfmc-core-network-live-ops-bridge-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 113,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-theory-spine-v86e",
    "title": "TRFMC v0.86E · Theory Spine",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_theory_spine_v86e.html",
    "route": "#trfmc-theory-spine-v86e",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 113,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-perfection-authority-v1",
    "title": "TRFMC Perfection Authority V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_perfection_authority_v1.html",
    "route": "#trfmc-perfection-authority-v1",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 112,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-official-safe-entrypoint-v6r3-command-center",
    "title": "TRFMC V6R3 Command Center",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    "route": "#trfmc-official-safe-entrypoint-v6r3-command-center",
    "status": "reference",
    "mode": "core-shell-reference",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 110,
    "shellScore": 9,
    "canvas": 1,
    "iframe": 1,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link",
      "iframe"
    ],
    "target": "reference-only",
    "description": "core-shell-reference"
  },
  {
    "id": "rf-telco-component-library-v76",
    "title": "TRFMC v0.76A · RF/Telco Component Object Library",
    "category": "antenna-system",
    "source": "frontend/public/rf_telco_component_library_v76.html",
    "route": "#rf-telco-component-library-v76",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 110,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-portal-link-graph-v1",
    "title": "TRFMC Portal Link Graph V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_portal_link_graph_v1.html",
    "route": "#trfmc-portal-link-graph-v1",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 109,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-rf-pro-signal-intelligence-lab-v4-instrument",
    "title": "TRFMC RF PRO Signal Intelligence Lab V4 Instrument",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_pro_signal_intelligence_lab_v4_instrument.html",
    "route": "#trfmc-rf-pro-signal-intelligence-lab-v4-instrument",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 109,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-telco-mission-portal-v35",
    "title": "TRFMC v0.35 RF/Telco Mission Portal",
    "category": "antenna-system",
    "source": "frontend/public/rf_telco_mission_portal_v35.html",
    "route": "#rf-telco-mission-portal-v35",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 108,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-perfection-authority-v2-scoped",
    "title": "TRFMC Perfection Authority V2 Scoped",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_perfection_authority_v2_scoped.html",
    "route": "#trfmc-perfection-authority-v2-scoped",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 108,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-perfection-authority-v3-scoped",
    "title": "TRFMC Perfection Authority V3 Scoped",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_perfection_authority_v3_scoped.html",
    "route": "#trfmc-perfection-authority-v3-scoped",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 108,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-soul-runtime-lab-v1",
    "title": "TRFMC Soul Runtime Lab V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_soul_runtime_lab_v1.html",
    "route": "#trfmc-soul-runtime-lab-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 107,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "infrastructure-digital-twin-v63",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.63B · Infrastructure Digital Twin Visual Upgrade",
    "category": "antenna-system",
    "source": "frontend/public/infrastructure_digital_twin_v63.html",
    "route": "#infrastructure-digital-twin-v63",
    "status": "reference",
    "mode": "reference-or-promote",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 104,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-rf-pro-signal-intelligence-lab-v2",
    "title": "TRFMC RF PRO Signal Intelligence Lab V2",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_pro_signal_intelligence_lab_v2.html",
    "route": "#trfmc-rf-pro-signal-intelligence-lab-v2",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 104,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-supervisor-mission-control-v5",
    "title": "TRFMC V5 Legacy Supervisor - Service Only",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_supervisor_mission_control_v5.html",
    "route": "#trfmc-supervisor-mission-control-v5",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 102,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-master-digital-twin-console-v1",
    "title": "TRFMC Master Digital Twin Console",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_master_digital_twin_console_v1.html",
    "route": "#trfmc-master-digital-twin-console-v1",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 100,
    "shellScore": 2,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-signal-intelligence-center-v1",
    "title": "TRFMC V6R4 Signal Intelligence Center",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_signal_intelligence_center_v1.html",
    "route": "#trfmc-signal-intelligence-center-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 100,
    "shellScore": 3,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "executive-mission-dashboard-v-next",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.59A · Executive Dashboard Next Enterprise Production Layer",
    "category": "war-room",
    "source": "frontend/public/executive_mission_dashboard_v_next.html",
    "route": "#executive-mission-dashboard-v-next",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 100,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-route-normalizer-v87f",
    "title": "TRFMC v0.87F · Route Normalizer",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_route_normalizer_v87f.html",
    "route": "#trfmc-route-normalizer-v87f",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 99,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-unified-shell-noiframe-v86d-r1",
    "title": "TRFMC v0.86D-R1 · No-IFrame Route Console",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_unified_shell_noiframe_v86d_r1.html",
    "route": "#trfmc-unified-shell-noiframe-v86d-r1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 99,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-antenna-rru-ret-cpri-port-mapping-v2",
    "title": "TRFMC Antenna / RRU / RET / CPRI Port Mapping V2",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v2.html",
    "route": "#trfmc-antenna-rru-ret-cpri-port-mapping-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 98,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-unified-shell-prototype-v86d",
    "title": "TRFMC v86D Quarantine · Route Locked",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_unified_shell_prototype_v86d.html",
    "route": "#trfmc-unified-shell-prototype-v86d",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 98,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-instrument-design-system-lab-v1",
    "title": "TRFMC Instrument Design System Lab V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_instrument_design_system_lab_v1.html",
    "route": "#trfmc-instrument-design-system-lab-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 97,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "executive-mission-dashboard-v40",
    "title": "TRFMC v0.40 Executive Mission Dashboard",
    "category": "fft-dsp-signal",
    "source": "frontend/public/executive_mission_dashboard_v40.html",
    "route": "#executive-mission-dashboard-v40",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 97,
    "shellScore": 3,
    "canvas": 0,
    "iframe": 0,
    "script": 15,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-cyber-rf-intelligence-evidence-v1",
    "title": "Cyber RF Intelligence / Evidence Lab",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_cyber_rf_intelligence_evidence_v1.html",
    "route": "#trfmc-cyber-rf-intelligence-evidence-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 97,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-unified-instrument-shell-lab-v1",
    "title": "TRFMC Unified Instrument Shell Lab V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_unified_instrument_shell_lab_v1.html",
    "route": "#trfmc-unified-instrument-shell-lab-v1",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 96,
    "shellScore": 3,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-realtime-fft-gapless-receiver-lab-v1",
    "title": "TRFMC Real-Time FFT / Gapless Receiver Lab",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_realtime_fft_gapless_receiver_lab_v1.html",
    "route": "#trfmc-realtime-fft-gapless-receiver-lab-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 96,
    "shellScore": 2,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "rf-telco-visual-cockpit-v36",
    "title": "TRFMC v0.36 RF/Telco Visual Scenario Cockpit",
    "category": "5g-core-ran",
    "source": "frontend/public/rf_telco_visual_cockpit_v36.html",
    "route": "#rf-telco-visual-cockpit-v36",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 93,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-unified-navigation-shell-v1",
    "title": "TRFMC Unified Navigation Shell V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_unified_navigation_shell_v1.html",
    "route": "#trfmc-unified-navigation-shell-v1",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 92,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-rf-antenna-academy-wall-v2-premium",
    "title": "TRFMC RF / Antenna Academy Wall V2 Premium",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_rf_antenna_academy_wall_v2_premium.html",
    "route": "#trfmc-rf-antenna-academy-wall-v2-premium",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 92,
    "shellScore": 1,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-orphan-quarantine-room-v1",
    "title": "TRFMC Orphan Quarantine Room V1",
    "category": "war-room",
    "source": "frontend/public/trfmc_orphan_quarantine_room_v1.html",
    "route": "#trfmc-orphan-quarantine-room-v1",
    "status": "reference",
    "mode": "promote-to-react-operational-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 92,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-operational-leaf"
  },
  {
    "id": "trfmc-canonical-navigation-map-v1",
    "title": "TRFMC Canonical Navigation Map V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_canonical_navigation_map_v1.html",
    "route": "#trfmc-canonical-navigation-map-v1",
    "status": "candidate",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 91,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "core-shell-reference"
  },
  {
    "id": "rfpro-unified-console",
    "title": "RF PRO · SDR Laboratory Receiver",
    "category": "5g-core-ran",
    "source": "frontend/public/rfpro_unified_console.html",
    "route": "#rfpro-unified-console",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 90,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-lab-v1",
    "title": "TRFMC 3D RF Asset Renderer Lab",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_lab_v1.html",
    "route": "#trfmc-3d-rf-asset-renderer-lab-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 90,
    "shellScore": 2,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-lab-v1r1-proportions",
    "title": "TRFMC 3D RF Asset Renderer Lab V1R1 Proportions",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_lab_v1r1_proportions.html",
    "route": "#trfmc-3d-rf-asset-renderer-lab-v1r1-proportions",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 90,
    "shellScore": 2,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-lab-v1r2-auto-fit",
    "title": "TRFMC 3D RF Asset Renderer Lab V1R2 Auto Fit",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_lab_v1r2_auto_fit.html",
    "route": "#trfmc-3d-rf-asset-renderer-lab-v1r2-auto-fit",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 90,
    "shellScore": 2,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-official-safe-entrypoint-v6r2-premium-console",
    "title": "TRFMC V6R2 Premium Instrument Console",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_official_safe_entrypoint_v6r2_premium_console.html",
    "route": "#trfmc-official-safe-entrypoint-v6r2-premium-console",
    "status": "reference",
    "mode": "core-shell-reference",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 90,
    "shellScore": 6,
    "canvas": 0,
    "iframe": 1,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link",
      "iframe"
    ],
    "target": "reference-only",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-visual-asset-engine-lab-v3",
    "title": "TRFMC Visual Asset Engine Lab V3",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_visual_asset_engine_lab_v3.html",
    "route": "#trfmc-visual-asset-engine-lab-v3",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 89,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-official-safe-entrypoint-v6",
    "title": "-",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_official_safe_entrypoint_v6.html",
    "route": "#trfmc-official-safe-entrypoint-v6",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 87,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-rf-antenna-theory-engine-v1",
    "title": "TRFMC RF Antenna Theory Engine V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_rf_antenna_theory_engine_v1.html",
    "route": "#trfmc-rf-antenna-theory-engine-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 86,
    "shellScore": 2,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "sapienza-master-template-doctrine-v85a",
    "title": "TRFMC v0.85A · Sapienza Master Template Doctrine",
    "category": "fft-dsp-signal",
    "source": "frontend/public/sapienza_master_template_doctrine_v85a.html",
    "route": "#sapienza-master-template-doctrine-v85a",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 86,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-rf-pro-signal-intelligence-lab-v3-reality",
    "title": "TRFMC RF PRO Signal Intelligence Lab V3 Reality",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_pro_signal_intelligence_lab_v3_reality.html",
    "route": "#trfmc-rf-pro-signal-intelligence-lab-v3-reality",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 85,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-rf-pro-signal-intelligence-lab-v1",
    "title": "TRFMC RF PRO Signal Intelligence Lab V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "route": "#trfmc-rf-pro-signal-intelligence-lab-v1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 84,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-webgl-v2r2-reality",
    "title": "TRFMC 3D RF Asset Renderer WebGL V2R2 Reality",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r2_reality.html",
    "route": "#trfmc-3d-rf-asset-renderer-webgl-v2r2-reality",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 83,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-final-promotion-gate-v1",
    "title": "TRFMC Final Promotion Gate V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_final_promotion_gate_v1.html",
    "route": "#trfmc-final-promotion-gate-v1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 83,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-true-portal-command-deck-v1",
    "title": "TRFMC True Portal Command Deck V1",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_true_portal_command_deck_v1.html",
    "route": "#trfmc-true-portal-command-deck-v1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 82,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-knowledge-base-theory-procedures-v1",
    "title": "Knowledge Base / Theory / Procedures Atlas",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_knowledge_base_theory_procedures_v1.html",
    "route": "#trfmc-knowledge-base-theory-procedures-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 81,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rf-instrumentation-signal-cockpit-v38",
    "title": "TRFMC v0.38 RF Instrumentation & Signal Analysis Cockpit",
    "category": "fft-dsp-signal",
    "source": "frontend/public/rf_instrumentation_signal_cockpit_v38.html",
    "route": "#rf-instrumentation-signal-cockpit-v38",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 79,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-rru-ret-cpri-port-mapping-v3",
    "title": "TRFMC Antenna / RRU / RET / CPRI Port Mapping V3 Engineering",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v3.html",
    "route": "#trfmc-antenna-rru-ret-cpri-port-mapping-v3",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 78,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-rru-ret-cpri-port-mapping-v4-reality",
    "title": "TRFMC Antenna / RRU / RET / CPRI Port Mapping V4 Reality",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v4_reality.html",
    "route": "#trfmc-antenna-rru-ret-cpri-port-mapping-v4-reality",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 78,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-antenna-rru-ret-cpri-port-mapping-v5-reality-asset",
    "title": "TRFMC Antenna / RRU / RET / CPRI V5 Reality Asset Painter",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_antenna_rru_ret_cpri_port_mapping_v5_reality_asset.html",
    "route": "#trfmc-antenna-rru-ret-cpri-port-mapping-v5-reality-asset",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 78,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-rf-metrology-calibration-lab-v1",
    "title": "TRFMC RF Metrology / Calibration Lab",
    "category": "rf-metrology",
    "source": "frontend/public/trfmc_rf_metrology_calibration_lab_v1.html",
    "route": "#trfmc-rf-metrology-calibration-lab-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 78,
    "shellScore": 2,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-orphan-consolidation-dossier-v1",
    "title": "TRFMC Orphan Consolidation Dossier V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_orphan_consolidation_dossier_v1.html",
    "route": "#trfmc-orphan-consolidation-dossier-v1",
    "status": "reference",
    "mode": "reference-or-promote",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 77,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-orphan-triage-board-v1",
    "title": "TRFMC Orphan Triage Board V1",
    "category": "fft-dsp-signal",
    "source": "frontend/public/trfmc_orphan_triage_board_v1.html",
    "route": "#trfmc-orphan-triage-board-v1",
    "status": "reference",
    "mode": "reference-or-promote",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 77,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-fiber-fronthaul-otdr-workbench-v1",
    "title": "Fiber / Fronthaul / OTDR Workbench",
    "category": "fiber-optic",
    "source": "frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v1.html",
    "route": "#trfmc-fiber-fronthaul-otdr-workbench-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 77,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-cinematic-command-deck-v87d",
    "title": "TRFMC v0.87D · Cinematic Command Deck",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_cinematic_command_deck_v87d.html",
    "route": "#trfmc-cinematic-command-deck-v87d",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 77,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-cinematic-mission-atlas-v87c",
    "title": "TRFMC v0.87C · Cinematic Mission Atlas",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_cinematic_mission_atlas_v87c.html",
    "route": "#trfmc-cinematic-mission-atlas-v87c",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 77,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-home-v87e",
    "title": "TRFMC v0.87E-R3 · Home Promotion Gate",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_home_v87e.html",
    "route": "#trfmc-home-v87e",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 77,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "signal-workbench-v580",
    "title": "RF PRO v5.8.0 · Signal Workbench",
    "category": "fft-dsp-signal",
    "source": "frontend/public/signal_workbench_v580.html",
    "route": "#signal-workbench-v580",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 75,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "signal-workbench-v582",
    "title": "RF PRO v5.8.2 · Signal Workbench Restored",
    "category": "fft-dsp-signal",
    "source": "frontend/public/signal_workbench_v582.html",
    "route": "#signal-workbench-v582",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 75,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc",
    "title": "TRFMC v0.87G · Public Operational Home",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc.html",
    "route": "#trfmc",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 75,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 6,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-webgl-v2",
    "title": "TRFMC 3D RF Asset Renderer WebGL V2",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2.html",
    "route": "#trfmc-3d-rf-asset-renderer-webgl-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 73,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-3d-rf-asset-renderer-webgl-v2r1-detail-boost",
    "title": "TRFMC 3D RF Asset Renderer WebGL V2R1 Detail Boost",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_3d_rf_asset_renderer_webgl_v2r1_detail_boost.html",
    "route": "#trfmc-3d-rf-asset-renderer-webgl-v2r1-detail-boost",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 73,
    "shellScore": 2,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-collaudo-report",
    "title": "TRFMC Collaudo Portale 5173",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_collaudo_report.html",
    "route": "#trfmc-collaudo-report",
    "status": "reference",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": 72,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [],
    "target": "reference-only",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-microwave-link-operations-center-v1",
    "title": "Microwave Link Operations Center",
    "category": "microwave-link",
    "source": "frontend/public/trfmc_microwave_link_operations_center_v1.html",
    "route": "#trfmc-microwave-link-operations-center-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 67,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-private-networks-wifi7-5g-mesh-v1",
    "title": "Private Networks / Wi-Fi 7 / 5G Mesh Lab",
    "category": "wifi-qam",
    "source": "frontend/public/trfmc_private_networks_wifi7_5g_mesh_v1.html",
    "route": "#trfmc-private-networks-wifi7-5g-mesh-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 67,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-portal-registry-v86c-r1",
    "title": "TRFMC v0.86C-R1 · Portal Registry Navigation Spine R1",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_portal_registry_v86c_r1.html",
    "route": "#trfmc-portal-registry-v86c-r1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 63,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-reset-browser-state-v6r1",
    "title": "-",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_reset_browser_state_v6r1.html",
    "route": "#trfmc-reset-browser-state-v6r1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 61,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-visual-qa-matrix-v71",
    "title": "TRFMC v0.71A · Page-by-Page Visual QA Matrix",
    "category": "microwave-link",
    "source": "frontend/public/trfmc_visual_qa_matrix_v71.html",
    "route": "#trfmc-visual-qa-matrix-v71",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 60,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 7,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "rfpro-realtime-v585",
    "title": "RF PRO v5.8.5 · Realtime Console",
    "category": "fft-dsp-signal",
    "source": "frontend/public/rfpro_realtime_v585.html",
    "route": "#rfpro-realtime-v585",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 58,
    "shellScore": 0,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-rf-microwave-engineering",
    "title": "TRFMC RF Microwave Engineering",
    "category": "microwave-link",
    "source": "frontend/public/trfmc_rf_microwave_engineering.html",
    "route": "#trfmc-rf-microwave-engineering",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 58,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 5,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-rf-physics-theory-atlas-v1",
    "title": "RF Physics Theory Atlas",
    "category": "knowledge-academy",
    "source": "frontend/public/trfmc_rf_physics_theory_atlas_v1.html",
    "route": "#trfmc-rf-physics-theory-atlas-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 57,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-datacenter-power-pdu-infrastructure-v1",
    "title": "Data Center / Power / PDU Infrastructure Lab",
    "category": "noc-operations",
    "source": "frontend/public/trfmc_datacenter_power_pdu_infrastructure_v1.html",
    "route": "#trfmc-datacenter-power-pdu-infrastructure-v1",
    "status": "candidate-visual",
    "mode": "promote-to-react-visual-leaf",
    "priority": "P1_VISUAL_LEAF",
    "promotionScore": 57,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "promote-to-react-visual-leaf"
  },
  {
    "id": "trfmc-change-control-policy-v1",
    "title": "TRFMC Change Control Policy V1",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_change_control_policy_v1.html",
    "route": "#trfmc-change-control-policy-v1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 53,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-post-promotion-control-center-v1",
    "title": "TRFMC Post-Promotion Control Center V1",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_post_promotion_control_center_v1.html",
    "route": "#trfmc-post-promotion-control-center-v1",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 53,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "trfmc-runtime-hook-layer-v1",
    "title": "TRFMC Runtime Hook Layer V1",
    "category": "5g-core-ran",
    "source": "frontend/public/trfmc_runtime_hook_layer_v1.html",
    "route": "#trfmc-runtime-hook-layer-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 48,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-microwave-link-operations-center-v2",
    "title": "TRFMC Microwave Link Operations Center V2",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_microwave_link_operations_center_v2.html",
    "route": "#trfmc-microwave-link-operations-center-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 48,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "rfpro-fullband-v586",
    "title": "RF PRO v5.8.6 · Full Band Cursor RTSA",
    "category": "fft-dsp-signal",
    "source": "frontend/public/rfpro_fullband_v586.html",
    "route": "#rfpro-fullband-v586",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 48,
    "shellScore": 0,
    "canvas": 4,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "signal-demod-v581",
    "title": "RF PRO v5.8.1 · IQ Analysis & Demod PRO",
    "category": "fft-dsp-signal",
    "source": "frontend/public/signal_demod_v581.html",
    "route": "#signal-demod-v581",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 39,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-rf-microwave-engineering-v1",
    "title": "TRFMC RF Microwave Engineering - Smith Chart Lab",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_rf_microwave_engineering_v1.html",
    "route": "#trfmc-rf-microwave-engineering-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 32,
    "shellScore": 0,
    "canvas": 2,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-integration-control-room",
    "title": "TRFMC Integration Control Room V2",
    "category": "antenna-system",
    "source": "frontend/public/trfmc_integration_control_room.html",
    "route": "#trfmc-integration-control-room",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 29,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "rfpro-master-v583",
    "title": "RF PRO v5.8.3 · Master Console",
    "category": "fft-dsp-signal",
    "source": "frontend/public/rfpro_master_v583.html",
    "route": "#rfpro-master-v583",
    "status": "quarantine-review",
    "mode": "core-shell-reference",
    "priority": "P2_REVIEW",
    "promotionScore": 28,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 6,
    "risks": [
      "dangerous_dom"
    ],
    "target": "manual-review",
    "description": "core-shell-reference"
  },
  {
    "id": "trfmc-fiber-fronthaul-otdr-workbench-v2",
    "title": "TRFMC Fiber / Fronthaul / OTDR Workbench V2",
    "category": "fiber-optic",
    "source": "frontend/public/trfmc_fiber_fronthaul_otdr_workbench_v2.html",
    "route": "#trfmc-fiber-fronthaul-otdr-workbench-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 28,
    "shellScore": 0,
    "canvas": 3,
    "iframe": 0,
    "script": 4,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-visual-master-preview-v1",
    "title": "TRFMC Visual Master Preview V1",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_visual_master_preview_v1.html",
    "route": "#trfmc-visual-master-preview-v1",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 23,
    "shellScore": 1,
    "canvas": 1,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "network-journey-world-map-v37",
    "title": "TRFMC v0.37 Network Journey World Map",
    "category": "antenna-system",
    "source": "frontend/public/network_journey_world_map_v37.html",
    "route": "#network-journey-world-map-v37",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "observability-console-v13",
    "title": "TRFMC v0.13 Observability & Evidence Console",
    "category": "antenna-system",
    "source": "frontend/public/observability_console_v13.html",
    "route": "#observability-console-v13",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "scenario-report-console-v17",
    "title": "TRFMC v0.17 Scenario Evidence Report Export",
    "category": "antenna-system",
    "source": "frontend/public/scenario_report_console_v17.html",
    "route": "#scenario-report-console-v17",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "scenario-runner-console-v16",
    "title": "TRFMC v0.16 Scenario Runner & Mission Playbooks",
    "category": "antenna-system",
    "source": "frontend/public/scenario_runner_console_v16.html",
    "route": "#scenario-runner-console-v16",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "evidence-vault-console-v20",
    "title": "TRFMC v0.20 Evidence Vault",
    "category": "war-room",
    "source": "frontend/public/evidence_vault_console_v20.html",
    "route": "#evidence-vault-console-v20",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "security-console-v18",
    "title": "TRFMC v0.18 Security Baseline & Access Guard",
    "category": "war-room",
    "source": "frontend/public/security_console_v18.html",
    "route": "#security-console-v18",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 20,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "uav-fhss-v584",
    "title": "RF PRO v5.8.4 · UAV FHSS / Burst",
    "category": "fft-dsp-signal",
    "source": "frontend/public/uav_fhss_v584.html",
    "route": "#uav-fhss-v584",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 19,
    "shellScore": 0,
    "canvas": 1,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "timeline-console-v14",
    "title": "TRFMC v0.14 Evidence Timeline & Mission Replay",
    "category": "antenna-system",
    "source": "frontend/public/timeline_console_v14.html",
    "route": "#timeline-console-v14",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 16,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-gpu-visual-runtime-lab-v2",
    "title": "TRFMC GPU Visual Runtime Lab V2",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_gpu_visual_runtime_lab_v2.html",
    "route": "#trfmc-gpu-visual-runtime-lab-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 14,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 4,
    "risks": [
      "cdn",
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-emergency-reset-layout-state",
    "title": "TRFMC Emergency Reset Layout State",
    "category": "signal-intelligence",
    "source": "frontend/public/trfmc_emergency_reset_layout_state.html",
    "route": "#trfmc-emergency-reset-layout-state",
    "status": "candidate",
    "mode": "reference-or-promote",
    "priority": "P2_REVIEW",
    "promotionScore": 11,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "html_runtime_link"
    ],
    "target": "promote-react",
    "description": "reference-or-promote"
  },
  {
    "id": "portal-index-v19",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.30 Portal Index Golden Check Integration",
    "category": "fft-dsp-signal",
    "source": "frontend/public/portal_index_v19.html",
    "route": "#portal-index-v19",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 7,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-integration-control-room-v2",
    "title": "TRFMC Integration Control Room V2",
    "category": "3d-rf-visual-twin",
    "source": "frontend/public/trfmc_integration_control_room_v2.html",
    "route": "#trfmc-integration-control-room-v2",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": 1,
    "shellScore": 0,
    "canvas": 0,
    "iframe": 0,
    "script": 1,
    "risks": [
      "dangerous_dom"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "global-mission-scenario-launcher-v39",
    "title": "TRFMC v0.39 Global Mission Scenario Launcher",
    "category": "noc-operations",
    "source": "frontend/public/global_mission_scenario_launcher_v39.html",
    "route": "#global-mission-scenario-launcher-v39",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -16,
    "shellScore": 3,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "runtime-golden-check-console-v29",
    "title": "TRFMC v0.70A Unified Shell · TRFMC v0.29 Runtime Golden Check Console",
    "category": "noc-operations",
    "source": "frontend/public/runtime_golden_check_console_v29.html",
    "route": "#runtime-golden-check-console-v29",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -23,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 3,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "mission-graph-console-v15",
    "title": "TRFMC v0.15 Correlation Engine & Mission Graph",
    "category": "signal-intelligence",
    "source": "frontend/public/mission_graph_console_v15.html",
    "route": "#mission-graph-console-v15",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -30,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "external_url",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "operator-handbook-console-v23",
    "title": "TRFMC v0.27 Operator Handbook Interactive Console",
    "category": "signal-intelligence",
    "source": "frontend/public/operator_handbook_console_v23.html",
    "route": "#operator-handbook-console-v23",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -30,
    "shellScore": 2,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "operational-backup-console-v21",
    "title": "TRFMC v0.21 Operational Backup Control",
    "category": "signal-intelligence",
    "source": "frontend/public/operational_backup_console_v21.html",
    "route": "#operational-backup-console-v21",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -34,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "restore-readiness-console-v22",
    "title": "TRFMC v0.22 Restore Readiness",
    "category": "signal-intelligence",
    "source": "frontend/public/restore_readiness_console_v22.html",
    "route": "#restore-readiness-console-v22",
    "status": "reference-risk",
    "mode": "reference-only-risk",
    "priority": "P2_REVIEW",
    "promotionScore": -34,
    "shellScore": 1,
    "canvas": 0,
    "iframe": 0,
    "script": 2,
    "risks": [
      "dangerous_dom",
      "html_runtime_link"
    ],
    "target": "reference-only",
    "description": "reference-only-risk"
  },
  {
    "id": "trfmc-official-safe-entrypoint-v6r1-flat",
    "title": "TRFMC V6R1 Flat",
    "category": "wifi-qam",
    "source": "frontend/public/trfmc_official_safe_entrypoint_v6r1_flat.html",
    "route": "#trfmc-official-safe-entrypoint-v6r1-flat",
    "status": "reference",
    "mode": "core-shell-reference",
    "priority": "P0_CORE_REFERENCE",
    "promotionScore": -42,
    "shellScore": 3,
    "canvas": 0,
    "iframe": 1,
    "script": 1,
    "risks": [
      "dangerous_dom",
      "html_runtime_link",
      "iframe"
    ],
    "target": "reference-only",
    "description": "core-shell-reference"
  }
]

export const promotedPortalOSModules = portalOSModules.filter((module) => module.status === 'promoted')
export const candidatePortalOSModules = portalOSModules.filter((module) => String(module.status).startsWith('candidate'))
export const referencePortalOSModules = portalOSModules.filter((module) => String(module.status).startsWith('reference'))
export const reviewPortalOSModules = portalOSModules.filter((module) => String(module.status).includes('review'))
export const visualPortalOSModules = portalOSModules.filter((module) => module.canvas && module.canvas > 0)
export const riskyPortalOSModules = portalOSModules.filter((module) => module.risks && module.risks.length > 0)
export const portalOSCategories = Array.from(new Set(portalOSModules.map((module) => module.category))).sort()
