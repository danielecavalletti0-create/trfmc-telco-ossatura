"""
app/shared/rf_interference.py

Formule di electronic warfare / spread-spectrum, standard da manuale
(es. Dixon "Spread Spectrum Systems", Proakis "Digital Communications",
Adamy "EW 101/102"). Sono le stesse formule insegnate in qualsiasi corso
universitario di comunicazioni e usate per progettare sistemi ANTI-jam
(GPS, satcom militari e civili) - conoscenza pubblica e difensiva.

Nessuna di queste funzioni controlla hardware o genera un segnale RF reale:
sono calcolatori puri, usati per popolare scenari di addestramento e
visualizzazioni (vedi app/domains/ew_lab/). Il modulo app/hardware/adapters
non espone alcun metodo di trasmissione (solo RX) - verificato nell'audit
del 2026-09-09 e confermato invariato.
"""
import math

from app.shared import rf_physics as ph


def js_ratio_db(
    jammer_eirp_dbw: float,
    jammer_distance_km: float,
    jammer_freq_hz: float,
    signal_received_power_dbw: float,
) -> float:
    """
    Rapporto Jamming-to-Signal al ricevitore vittima, in dB:
        J/S = Pr_jammer - Pr_segnale

    Riusa la stessa catena FSPL/link-budget gia' verificata in rf_physics
    (il jammer e' semplicemente un secondo trasmettitore che raggiunge lo
    stesso ricevitore).
    """
    fspl_jammer = ph.fspl_db(jammer_distance_km * 1000.0, jammer_freq_hz)
    pr_jammer = jammer_eirp_dbw - fspl_jammer
    return pr_jammer - signal_received_power_dbw


def bandwidth_correction_db(jammer_bandwidth_hz: float, victim_bandwidth_hz: float) -> float:
    """
    Correzione di J/S per la sovrapposizione di banda: se il jammer spande
    la potenza su una banda piu' larga di quella del ricevitore vittima
    (jamming a "barrage"/rumore), solo la frazione di potenza che cade
    nella banda del ricevitore lo disturba realmente:
        correzione_dB = 10*log10(min(1, B_vittima / B_jammer))

    Un jammer "spot" (banda stretta, tutta dentro la banda vittima) ha
    correzione 0dB (nessuna perdita). Un jammer a barrage largo il doppio
    della banda vittima perde 3dB di efficacia, e cosi' via.
    """
    if jammer_bandwidth_hz <= 0 or victim_bandwidth_hz <= 0:
        raise ValueError("le larghezze di banda devono essere positive")
    ratio = min(1.0, victim_bandwidth_hz / jammer_bandwidth_hz)
    return 10.0 * math.log10(ratio)


def burn_through_range_km(
    jammer_eirp_dbw: float,
    jammer_freq_hz: float,
    signal_received_power_dbw: float,
    js_threshold_db: float,
) -> float:
    """
    Distanza di "burn-through": la distanza dal jammer oltre la quale J/S
    scende sotto la soglia richiesta (il link vittima torna utilizzabile).
    FSPL e' lineare in log10(d), quindi l'equazione si risolve analiticamente:

        J/S_dB = EIRP_j - FSPL(d) - Pr_segnale = soglia
        FSPL(d) = EIRP_j - Pr_segnale - soglia
        20*log10(4*pi*d*f/c) = quel valore  ->  si isola d
    """
    target_fspl_db = jammer_eirp_dbw - signal_received_power_dbw - js_threshold_db
    # FSPL_dB = 20*log10(4*pi*f/c) + 20*log10(d) -> risolvo per d
    k = 20.0 * math.log10(4.0 * math.pi * jammer_freq_hz / ph.SPEED_OF_LIGHT_M_S)
    log10_d_m = (target_fspl_db - k) / 20.0
    d_m = 10.0 ** log10_d_m
    return d_m / 1000.0


def fhss_hit_probability(jammer_bandwidth_hz: float, hopping_bandwidth_hz: float) -> float:
    """
    Probabilita' che un singolo salto di frequenza (frequency hopping)
    cada dentro la porzione di banda occupata da un jammer a banda
    parziale (partial-band jamming):
        P_hit = B_jammer / B_hopping_totale

    Formula standard di teoria dello spread-spectrum (es. Dixon,
    "Spread Spectrum Systems", cap. sulla resistenza al jamming
    partial-band del frequency hopping). Un jammer che copre l'intera
    banda di hopping ha P_hit=1 (nessun vantaggio dal hopping); un
    jammer su 1/10 della banda ha P_hit=0.1.
    """
    if hopping_bandwidth_hz <= 0:
        raise ValueError("hopping_bandwidth_hz deve essere positiva")
    return min(1.0, max(0.0, jammer_bandwidth_hz / hopping_bandwidth_hz))


def sweep_jammer_duty_cycle(victim_bandwidth_hz: float, sweep_total_bandwidth_hz: float) -> float:
    """
    Frazione di tempo per cui un jammer a scansione (sweep, che percorre
    l'intera banda ciclicamente a velocita' costante) sta effettivamente
    disturbando una vittima a banda stretta, assunta scansione a velocita'
    angolare/frequenziale costante:
        duty_cycle = B_vittima / B_scansione_totale

    Approssimazione standard per uno sweep lineare a velocita' costante
    (il tempo di permanenza su una sotto-banda e' proporzionale alla sua
    larghezza rispetto alla banda totale spazzata).
    """
    if sweep_total_bandwidth_hz <= 0:
        raise ValueError("sweep_total_bandwidth_hz deve essere positiva")
    return min(1.0, max(0.0, victim_bandwidth_hz / sweep_total_bandwidth_hz))


def cinr_db(carrier_dbw: float, noise_dbw: float, interference_dbw: float) -> float:
    """
    Carrier-to-Interference-plus-Noise Ratio: la metrica corretta quando sono
    presenti sia rumore termico sia jamming. Rumore e interferenza si
    sommano in POTENZA LINEARE, non si possono sottrarre direttamente in dB
    (errore comune): bisogna convertire, sommare, poi riconvertire.
    """
    noise_w = 10.0 ** (noise_dbw / 10.0)
    interference_w = 10.0 ** (interference_dbw / 10.0)
    total_w = noise_w + interference_w
    total_dbw = 10.0 * math.log10(total_w)
    return carrier_dbw - total_dbw


def effective_js_db(
    js_raw_db: float,
    jammer_bandwidth_hz: float,
    victim_bandwidth_hz: float,
    jammer_type: str,
) -> float:
    """
    J/S "effettivo" tenendo conto del tipo di jammer:
      - spot: tutta la potenza in banda, nessuna correzione
      - barrage: corretto per la diluizione di banda (vedi bandwidth_correction_db)
      - sweep: corretto per il duty cycle (il jammer non e' sempre in banda)
    """
    if jammer_type == "spot":
        return js_raw_db
    if jammer_type == "barrage":
        return js_raw_db + bandwidth_correction_db(jammer_bandwidth_hz, victim_bandwidth_hz)
    if jammer_type == "sweep":
        duty = sweep_jammer_duty_cycle(victim_bandwidth_hz, jammer_bandwidth_hz)
        # In banda al 100% quando colpisce: nessuna perdita di potenza di picco,
        # ma efficacia media ridotta dal duty cycle.
        return js_raw_db + 10.0 * math.log10(max(duty, 1e-9))
    raise ValueError(f"jammer_type sconosciuto: {jammer_type} (atteso: spot, barrage, sweep)")
