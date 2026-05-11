from app.domains.scientific_core.services import ScientificCoreService

def test_plane_wave_demo():
    svc = ScientificCoreService()
    r = svc.plane_wave(3.5e9, 1.0)
    assert r["wavelength_m"] > 0
    assert r["intrinsic_impedance_ohm"] > 300
    assert r["poynting_w_per_m2"] > 0
