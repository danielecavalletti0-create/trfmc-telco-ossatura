export type RFSourceMode =
  | "synthetic"
  | "file_iq"
  | "websocket_iq"
  | "sdr_bridge"
  | "open5gs_events";

export type RFSourceStatus =
  | "disabled"
  | "standby"
  | "ready"
  | "connected"
  | "streaming"
  | "error";

export type RFSourceDescriptor = {
  mode: RFSourceMode;
  label: string;
  status: RFSourceStatus;
  endpoint?: string;
  sampleRate?: number;
  centerFrequency?: number;
  bandwidth?: number;
  format?: "complex64" | "int16_iq" | "float32_iq" | "json_events" | "pcap_meta";
  safety: "synthetic_only" | "local_lab_only" | "read_only_bridge";
  notes: string;
};

export type RFBridgeFrameMeta = {
  source: RFSourceMode;
  timestamp: number;
  sequence: number;
  sampleRate?: number;
  centerFrequency?: number;
  bytes?: number;
  format?: string;
};

export type RFSourceHealth = {
  mode: RFSourceMode;
  status: RFSourceStatus;
  lastFrameAt?: number;
  frames: number;
  drops: number;
  message: string;
};

export const RF_SOURCE_DESCRIPTORS: RFSourceDescriptor[] = [
  {
    mode: "synthetic",
    label: "Synthetic DSP Worker",
    status: "ready",
    sampleRate: 122_880_000,
    centerFrequency: 2_440_000_000,
    bandwidth: 80_000_000,
    format: "float32_iq",
    safety: "synthetic_only",
    notes: "Current safe source. Generates synthetic RF/IQ evidence inside DSP Worker V3."
  },
  {
    mode: "file_iq",
    label: "File IQ Replay",
    status: "standby",
    endpoint: "local file / future upload pipeline",
    format: "complex64",
    safety: "local_lab_only",
    notes: "Prepared for offline IQ replay without touching live SDR."
  },
  {
    mode: "websocket_iq",
    label: "Binary WebSocket IQ",
    status: "standby",
    endpoint: "ws://127.0.0.1:8090/ws/iq",
    format: "float32_iq",
    safety: "local_lab_only",
    notes: "Prepared for ArrayBuffer IQ frames. Not auto-connected in V7."
  },
  {
    mode: "sdr_bridge",
    label: "SDR / HackRF Bridge",
    status: "standby",
    endpoint: "ws://127.0.0.1:8090/ws/sdr",
    format: "int16_iq",
    safety: "read_only_bridge",
    notes: "Future read-only bridge for SDR capture pipeline."
  },
  {
    mode: "open5gs_events",
    label: "Open5GS / UERANSIM Events",
    status: "standby",
    endpoint: "ws://127.0.0.1:8000/api/events/stream",
    format: "json_events",
    safety: "read_only_bridge",
    notes: "Future event correlation layer for NAS/NGAP/PFCP/GTP-U evidence."
  }
];
