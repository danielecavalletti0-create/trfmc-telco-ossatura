from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class NetworkSegment(BaseModel):
    segment_id: str
    sequence: int
    type: str
    source: str
    destination: str
    source_asset_id: Optional[str] = None
    target_asset_id: Optional[str] = None
    latency_ms: float
    jitter_ms: float
    packet_loss_percent: float
    capacity_mbps: Optional[float] = None
    utilization_percent: Optional[float] = None
    qos_class: str = "BEST_EFFORT"
    status: str = "NOMINAL"
    notes: Optional[str] = None


class NetworkPath(BaseModel):
    path_id: str
    mission_id: str
    service_type: str
    source: str
    destination_city: str
    destination_country: str
    destination_label: str
    path_layers: List[str]
    segments: List[NetworkSegment]
    estimated_rtt_ms: float
    mos_estimate: float
    dominant_latency_segment: str
    security_context: Dict[str, Any]
    qos_context: Dict[str, Any]
