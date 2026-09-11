"""
app/shared/rf_physics.py

Formule di fisica RF condivise e verificate, riusabili da piu' domini
(rf_coverage, satellite, ...). Ogni formula e' derivata da principi fisici
di base — non da costanti "a memoria" non verificabili — e documentata con
la sua derivazione, cosi' e' possibile ricontrollarla a mano.
"""
import math

SPEED_OF_LIGHT_M_S = 299_792_458.0
K_BOLTZMANN_J_PER_K = 1.380649e-23
# Costante di Boltzmann espressa in dBW/K/Hz: usata per calcolare la potenza
# di rumore termico N0 = k*T in forma logaritmica (N0_dBW_Hz = K_BOLTZMANN_DBW + 10*log10(T)).
K_BOLTZMANN_DBW_PER_K_HZ = 10.0 * math.log10(K_BOLTZMANN_J_PER_K)  # ~ -228.6
EARTH_RADIUS_KM = 6371.0
# Parametro gravitazionale standard della Terra (GM), usato per l'orbita
# circolare: v = sqrt(GM / r), periodo T = 2*pi*sqrt(r^3 / GM).
EARTH_MU_KM3_S2 = 398_600.4418


def fspl_db(distance_m: float, frequency_hz: float) -> float:
    """
    Free-Space Path Loss (equazione di Friis in forma logaritmica):
        FSPL_dB = 20*log10(4*pi*d*f/c)

    Derivazione diretta dall'equazione di Friis (Pr/Pt = Gt*Gr*(c/(4*pi*d*f))^2),
    nessuna costante "magica" non verificabile. Per d in metri e f in Hz
    equivale esattamente a 20*log10(d) + 20*log10(f) - 147.55 (convenzione
    gia' in uso in app/domains/rf_coverage/services.py, verificata identica
    a meno di arrotondamento).
    """
    if distance_m <= 0 or frequency_hz <= 0:
        raise ValueError("distance_m e frequency_hz devono essere positivi")
    return 20.0 * math.log10(4.0 * math.pi * distance_m * frequency_hz / SPEED_OF_LIGHT_M_S)


def knife_edge_diffraction_loss_db(
    obstacle_height_above_los_m: float,
    distance_tx_to_obstacle_m: float,
    distance_obstacle_to_rx_m: float,
    frequency_hz: float,
) -> float:
    """
    Perdita per diffrazione da ostacolo singolo (modello "knife-edge"),
    formula standard ITU-R Recommendation P.526 - lo stesso modello usato
    nei tool di pianificazione cellulare reali (Atoll, Pathloss, ecc.) per
    stimare la perdita quando un edificio ostruisce parzialmente o
    totalmente la linea di vista diretta.

    Parametro di diffrazione (adimensionale):
        v = h * sqrt(2/lambda * (1/d1 + 1/d2))
    dove h e' l'altezza della cima dell'ostacolo SOPRA la linea retta
    tx-rx (h negativo se la linea passa sopra l'ostacolo, libera).

    Perdita approssimata (valida per v > -0.78, ITU-R P.526):
        J(v) = 6.9 + 20*log10( sqrt((v-0.1)^2 + 1) + v - 0.1 )   dB
        J(v) = 0                                                  per v <= -0.78

    Valori di riferimento noti per verifica (citati in ogni manuale che
    tratta questo modello):
        v=0    (cima ostacolo esattamente sulla linea di vista) -> J~=6.02dB
        v=-0.78 (limite di prima zona di Fresnel quasi libera)  -> J~=0dB
        v=1                                                      -> J~=13.9dB
    """
    wavelength_m = SPEED_OF_LIGHT_M_S / frequency_hz
    d1 = max(distance_tx_to_obstacle_m, 1e-3)
    d2 = max(distance_obstacle_to_rx_m, 1e-3)

    v = obstacle_height_above_los_m * math.sqrt(
        (2.0 / wavelength_m) * (1.0 / d1 + 1.0 / d2)
    )

    if v <= -0.78:
        return 0.0

    j = 6.9 + 20.0 * math.log10(
        math.sqrt((v - 0.1) ** 2 + 1.0) + v - 0.1
    )
    return max(0.0, j)


def fresnel_zone_radius_m(
    distance_tx_to_point_m: float,
    distance_point_to_rx_m: float,
    frequency_hz: float,
    zone: int = 1,
) -> float:
    """
    Raggio della n-esima zona di Fresnel in un punto lungo il percorso
    (formula standard): r_n = sqrt(n * lambda * d1 * d2 / (d1 + d2)).
    Usata per valutare quanto margine di clearance serve perche' un
    ostacolo non causi diffrazione significativa (regola pratica: 60%
    della prima zona libera -> perdita da diffrazione trascurabile).
    """
    wavelength_m = SPEED_OF_LIGHT_M_S / frequency_hz
    d1 = max(distance_tx_to_point_m, 1e-3)
    d2 = max(distance_point_to_rx_m, 1e-3)
    return math.sqrt(zone * wavelength_m * d1 * d2 / (d1 + d2))


def eirp_dbw(tx_power_dbw: float, tx_antenna_gain_dbi: float) -> float:
    """EIRP (Equivalent Isotropically Radiated Power) = Pt + Gt, in dB."""
    return tx_power_dbw + tx_antenna_gain_dbi


def received_power_dbw(
    eirp_dbw_value: float,
    path_loss_db: float,
    rx_antenna_gain_dbi: float,
    other_losses_db: float = 0.0,
) -> float:
    """Equazione del link (forma logaritmica): Pr = EIRP - L_path + Gr - L_altre."""
    return eirp_dbw_value - path_loss_db + rx_antenna_gain_dbi - other_losses_db


def noise_power_dbw(system_noise_temp_k: float, bandwidth_hz: float) -> float:
    """
    Potenza di rumore termico N = k*T*B, in dBW.
    N_dBW = K_BOLTZMANN_DBW + 10*log10(T) + 10*log10(B)
    """
    if system_noise_temp_k <= 0 or bandwidth_hz <= 0:
        raise ValueError("system_noise_temp_k e bandwidth_hz devono essere positivi")
    return K_BOLTZMANN_DBW_PER_K_HZ + 10.0 * math.log10(system_noise_temp_k) + 10.0 * math.log10(bandwidth_hz)


def cn0_db_hz(received_power_dbw_value: float, system_noise_temp_k: float) -> float:
    """
    Rapporto portante/densita' di rumore C/N0, in dB-Hz (indipendente dalla
    larghezza di banda del canale - e' la metrica standard per confrontare
    link satellitari a prescindere dal modem usato):
        C/N0 = Pr_dBW - K_BOLTZMANN_DBW - 10*log10(T_sys)
    """
    if system_noise_temp_k <= 0:
        raise ValueError("system_noise_temp_k deve essere positiva")
    return received_power_dbw_value - K_BOLTZMANN_DBW_PER_K_HZ - 10.0 * math.log10(system_noise_temp_k)


def cn_db(cn0_db_hz_value: float, bandwidth_hz: float) -> float:
    """C/N nel canale = C/N0 - 10*log10(B)."""
    if bandwidth_hz <= 0:
        raise ValueError("bandwidth_hz deve essere positiva")
    return cn0_db_hz_value - 10.0 * math.log10(bandwidth_hz)


def satellite_geometry(
    ground_lat_deg: float,
    ground_lon_deg: float,
    sub_satellite_lat_deg: float,
    sub_satellite_lon_deg: float,
    satellite_altitude_km: float,
) -> dict:
    """
    Geometria stazione di terra <-> satellite (modello Terra sferica),
    formula standard da manuale di comunicazioni satellitari (es. Pratt &
    Bostian, "Satellite Communications"):

        cos(gamma) = sin(lat_gs)*sin(lat_ss) + cos(lat_gs)*cos(lat_ss)*cos(lon_ss-lon_gs)
        d = sqrt(Re^2 + Rs^2 - 2*Re*Rs*cos(gamma))
        elevazione = asin((Rs*cos(gamma) - Re) / d)

    dove gamma e' l'angolo centrale Terra tra stazione e punto sub-satellite,
    Re il raggio terrestre, Rs = Re + altitudine (raggio orbitale).

    Casi limite verificabili a mano:
      - satellite esattamente sopra la stazione (gamma=0) -> elevazione = 90 gradi
      - orizzonte (elevazione=0) per un satellite GEO -> gamma ~= 81.3 gradi
        (valore noto da manuale per la visibilita' GEO)
    """
    lat_gs = math.radians(ground_lat_deg)
    lat_ss = math.radians(sub_satellite_lat_deg)
    dlon = math.radians(sub_satellite_lon_deg - ground_lon_deg)

    cos_gamma = math.sin(lat_gs) * math.sin(lat_ss) + math.cos(lat_gs) * math.cos(lat_ss) * math.cos(dlon)
    cos_gamma = max(-1.0, min(1.0, cos_gamma))
    gamma = math.acos(cos_gamma)

    re = EARTH_RADIUS_KM
    rs = EARTH_RADIUS_KM + satellite_altitude_km

    slant_range_km = math.sqrt(re * re + rs * rs - 2.0 * re * rs * cos_gamma)

    if slant_range_km < 1e-6:
        elevation_deg = 90.0
    else:
        sin_el = (rs * cos_gamma - re) / slant_range_km
        sin_el = max(-1.0, min(1.0, sin_el))
        elevation_deg = math.degrees(math.asin(sin_el))

    return {
        "central_angle_deg": math.degrees(gamma),
        "slant_range_km": slant_range_km,
        "elevation_deg": elevation_deg,
        "visible": elevation_deg > 0.0,
    }


def orbital_angular_rate_rad_s(satellite_altitude_km: float) -> float:
    """
    Velocita' angolare di un'orbita circolare: omega = sqrt(GM / r^3).
    (Terza legge di Keplero in forma di velocita' angolare costante, valida
    per orbita circolare - approssimazione dichiarata, non propagazione SGP4.)
    """
    r = EARTH_RADIUS_KM + satellite_altitude_km
    return math.sqrt(EARTH_MU_KM3_S2 / (r ** 3))


def doppler_shift_hz(
    ground_lat_deg: float,
    ground_lon_deg: float,
    sub_satellite_lat_deg: float,
    sub_satellite_lon_deg: float,
    satellite_altitude_km: float,
    carrier_freq_hz: float,
    ground_track_heading_deg: float = 90.0,
    dt_s: float = 1.0,
) -> float:
    """
    Doppler shift stimato per differenziazione numerica del range (metodo
    onesto e verificabile: calcola la distanza slant-range al tempo t e a
    t+dt lungo la rotta a terra del satellite, approssimazione a orbita
    circolare, e deriva la velocita' radiale da li'):

        range_rate = (d(t+dt) - d(t)) / dt
        doppler_hz = -(range_rate_m_s / c) * f_carrier

    Semplificazione dichiarata: il punto sub-satellite si muove lungo una
    rotta di rilevamento costante (ground_track_heading_deg) alla velocita'
    angolare orbitale - non e' una propagazione orbitale completa (SGP4),
    ma la fisica del calcolo Doppler stesso (derivata numerica del range)
    e' corretta ed esatta rispetto al modello di moto assunto.
    """
    omega = orbital_angular_rate_rad_s(satellite_altitude_km)
    angular_step_deg = math.degrees(omega * dt_s)

    heading = math.radians(ground_track_heading_deg)
    dlat = angular_step_deg * math.cos(heading)
    dlon = angular_step_deg * math.sin(heading) / max(1e-6, math.cos(math.radians(sub_satellite_lat_deg)))

    geo_t0 = satellite_geometry(
        ground_lat_deg, ground_lon_deg,
        sub_satellite_lat_deg, sub_satellite_lon_deg,
        satellite_altitude_km,
    )
    geo_t1 = satellite_geometry(
        ground_lat_deg, ground_lon_deg,
        sub_satellite_lat_deg + dlat, sub_satellite_lon_deg + dlon,
        satellite_altitude_km,
    )

    range_rate_km_s = (geo_t1["slant_range_km"] - geo_t0["slant_range_km"]) / dt_s
    range_rate_m_s = range_rate_km_s * 1000.0

    return -(range_rate_m_s / SPEED_OF_LIGHT_M_S) * carrier_freq_hz
