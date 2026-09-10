from pydantic import BaseModel, Field


class LinkBudgetRequest(BaseModel):
    tx_power_dbw: float = Field(..., description="Potenza del trasmettitore, in dBW")
    tx_antenna_gain_dbi: float = Field(..., description="Guadagno antenna trasmittente, in dBi")
    rx_antenna_gain_dbi: float = Field(..., description="Guadagno antenna ricevente, in dBi")
    distance_km: float = Field(..., gt=0, description="Distanza slant-range, in km")
    frequency_hz: float = Field(..., gt=0, description="Frequenza portante, in Hz")
    system_noise_temp_k: float = Field(150.0, gt=0, description="Temperatura di rumore di sistema, in Kelvin")
    bandwidth_hz: float = Field(..., gt=0, description="Larghezza di banda del canale, in Hz")
    other_losses_db: float = Field(0.0, description="Perdite aggiuntive (atmosferiche, puntamento, ecc.), in dB")
    required_cn_db: float = Field(10.0, description="Soglia C/N richiesta dal modem/FEC, in dB")


class GeometryRequest(BaseModel):
    ground_lat_deg: float = Field(..., ge=-90, le=90)
    ground_lon_deg: float = Field(..., ge=-180, le=180)
