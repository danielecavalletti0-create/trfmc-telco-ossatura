import math
import random
import cmath

C0 = 299_792_458.0
MU0 = 4 * math.pi * 1e-7
EPS0 = 1.0 / (MU0 * C0 * C0)


class ScientificCoreService:
    def plane_wave(
        self,
        frequency_hz: float,
        electric_field_v_per_m: float,
        relative_permittivity=1.0,
        relative_permeability=1.0,
    ):
        eps = EPS0 * relative_permittivity
        mu = MU0 * relative_permeability

        phase_velocity = 1.0 / math.sqrt(mu * eps)
        wavelength = phase_velocity / frequency_hz
        omega = 2 * math.pi * frequency_hz
        beta = 2 * math.pi / wavelength
        intrinsic_impedance = math.sqrt(mu / eps)

        magnetic_field = electric_field_v_per_m / intrinsic_impedance
        poynting = electric_field_v_per_m * magnetic_field

        return {
            "frequency_hz": frequency_hz,
            "wavelength_m": wavelength,
            "omega_rad_s": omega,
            "beta_rad_m": beta,
            "phase_velocity_m_s": phase_velocity,
            "intrinsic_impedance_ohm": intrinsic_impedance,
            "electric_field_v_per_m": electric_field_v_per_m,
            "magnetic_field_a_per_m": magnetic_field,
            "poynting_w_per_m2": poynting,
            "notes": [
                "Uniform plane-wave model",
                "E perpendicular to H perpendicular to k",
                "S = E x H",
                "Pure-Python bootstrap implementation; NumPy/SciPy worker layer will be added later.",
            ],
        }

    def near_far(self, frequency_hz: float, antenna_max_dimension_m: float):
        wavelength = C0 / frequency_hz

        reactive_near_field_limit = 0.62 * math.sqrt(
            (antenna_max_dimension_m ** 3) / wavelength
        )

        fraunhofer_far_field_start = (
            2 * antenna_max_dimension_m ** 2 / wavelength
        )

        return {
            "wavelength_m": wavelength,
            "reactive_near_field_limit_m": reactive_near_field_limit,
            "fresnel_region_start_m": reactive_near_field_limit,
            "fresnel_region_end_m": fraunhofer_far_field_start,
            "fraunhofer_far_field_start_m": fraunhofer_far_field_start,
        }

    def qpsk_awgn(self, snr_db: float = 20.0, symbols: int = 256, seed: int = 12345):
        rng = random.Random(seed)

        ideal_symbols = []
        measured_symbols = []

        constellation = {
            (0, 0): complex(1, 1) / math.sqrt(2),
            (0, 1): complex(-1, 1) / math.sqrt(2),
            (1, 1): complex(-1, -1) / math.sqrt(2),
            (1, 0): complex(1, -1) / math.sqrt(2),
        }

        for _ in range(symbols):
            b0 = rng.randint(0, 1)
            b1 = rng.randint(0, 1)
            ideal_symbols.append(constellation[(b0, b1)])

        signal_power = sum(abs(x) ** 2 for x in ideal_symbols) / len(ideal_symbols)
        noise_power = signal_power / (10 ** (snr_db / 10.0))
        sigma = math.sqrt(noise_power / 2.0)

        noise_rng = random.Random(seed + 1)

        for sym in ideal_symbols:
            noise_i = noise_rng.gauss(0.0, sigma)
            noise_q = noise_rng.gauss(0.0, sigma)
            measured_symbols.append(sym + complex(noise_i, noise_q))

        err_power = sum(abs(m - r) ** 2 for m, r in zip(measured_symbols, ideal_symbols)) / len(ideal_symbols)
        ref_power = sum(abs(r) ** 2 for r in ideal_symbols) / len(ideal_symbols)
        evm_rms_percent = 100.0 * math.sqrt(err_power / ref_power)

        preview = [
            {"i": float(x.real), "q": float(x.imag)}
            for x in measured_symbols[:64]
        ]

        return {
            "model": "QPSK complex baseband + seeded AWGN",
            "seed": seed,
            "snr_db": snr_db,
            "evm_rms_percent": evm_rms_percent,
            "preview": preview,
        }
