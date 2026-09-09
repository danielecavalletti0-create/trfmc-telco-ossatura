from fastapi import APIRouter
from pydantic import BaseModel, Field
from app.domains.scientific_core.services import ScientificCoreService
router = APIRouter(prefix="/api/scientific", tags=["scientific-core"])
service = ScientificCoreService()
class PlaneWaveRequest(BaseModel):
    frequency_hz: float = Field(..., gt=0)
    electric_field_v_per_m: float = Field(..., gt=0)
    relative_permittivity: float = Field(1.0, gt=0)
    relative_permeability: float = Field(1.0, gt=0)
class NearFarRequest(BaseModel):
    frequency_hz: float = Field(..., gt=0)
    antenna_max_dimension_m: float = Field(..., gt=0)
@router.post("/plane-wave")
def plane_wave(req: PlaneWaveRequest): return service.plane_wave(**req.model_dump())
@router.get("/plane-wave/demo")
def plane_wave_demo(): return service.plane_wave(frequency_hz=3.5e9, electric_field_v_per_m=1.0)
@router.post("/near-far")
def near_far(req: NearFarRequest): return service.near_far(**req.model_dump())
@router.get("/near-far/demo")
def near_far_demo(): return service.near_far(frequency_hz=3.5e9, antenna_max_dimension_m=0.8)
@router.get("/qpsk-awgn/demo")
def qpsk_awgn_demo(snr_db: float=20.0, symbols: int=256, seed: int=12345): return service.qpsk_awgn(snr_db, symbols, seed)
