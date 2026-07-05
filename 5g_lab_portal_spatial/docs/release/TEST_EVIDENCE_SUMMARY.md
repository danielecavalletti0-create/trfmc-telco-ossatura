# Test Evidence Summary — 5G Lab Portal

Questo documento consolida l'evidenza di test **già raccolta** durante Patch 1-5D. Non introduce nuovi test (Patch 5E è documentale). Per le Patch 1-5B (portale statico), l'evidenza è riportata così come registrata durante quelle patch nella cronologia di questa sessione; per le Patch 5C/5D (Vite/React) l'evidenza include percorsi file concreti prodotti in questa stessa sessione.

## Build test

| Superficie | Comando | Esito registrato |
|---|---|---|
| Portale statico | N/A (nessun build step, HTML statico) | N/A |
| Backend statico (`main_engine.py`) | `python -m py_compile` (Patch 2) | PASS |
| Portale Vite/React | `npm run build` (`tsc -b && vite build`) | PASS (rieseguito 3 volte: dopo Patch 5C, dopo la correzione intermedia in 5C, dopo Patch 5D) |

## Route test — portale statico (11 pagine)

`index.html`, `protocol_console.html`, `core_console.html`, `alarms.html`, `signal_analyzer.html`, `architecture.html`, `multisite_network_twin.html`, `multirat_geo_twin.html`, `teoria5.html`, `spatial_simulator.html`, `spatial_theory.html` — tutte verificate caricare senza errori bloccanti durante Patch 4 (audit responsive) e Patch 5 (screenshot mirati su protocol/core/alarms).

## Responsive test — portale statico

Script Playwright (Patch 4): 11 pagine × 3 risoluzioni (1366×768, 1920×1080, 2560×1440) → **0 horizontal overflow, 0 errori console** su tutte le combinazioni.

## Route test — portale Vite/React (4 route)

Eseguito in questa sessione (Patch 5C/5D), script `patch5c_verify.mjs`:

| Route | Console err. | Network fail | Canvas 0-size | scrollY 1s/3s |
|---|---|---|---|---|
| `#live-ops` | 9 (CORS/404 preesistenti, invariati tra 5C e 5D) | 5 | 0 | 0/0 |
| `#sentinel-x` | 0 | 0 | 0 | 0/0 |
| `#instrument-lab` | 0 | 0 | 0 | 0/0 |
| `#sentinel-x-legacy` | 0 | 0 | 0 | 0/0 |

## Endpoint test

- `/api/health`, `/api/lab/status`, `/api/core/status`, `/api/core/events`, `/api/protocols/events`, `/api/alarms` (porta 8000): verificati funzionalmente durante Patch 2/3/5 (vedi `DATA_CONTRACT_5G_PORTAL.md` per stato per-endpoint).
- `/api/v16f/telemetry/fast` (porta 8090): verificato **fallire** con CORS/404 (Patch 5C, cattura diretta console/network).
- `ws://127.0.0.1:8090/ws/telemetry` (porta 8090): verificato con un probe diretto (script dedicato in questa sessione) — connessione riuscita, payload catturato e confrontato con lo schema atteso, confermando il disallineamento `{profile,kpi,state,beam}` vs `{rf,core}`.

## Backend health

`/api/health` (8000) verificato raggiungibile durante Patch 2 (dopo riavvio autorizzato del solo backend FastAPI). Non ri-testato in questa sessione documentale (5E).

## Open5GS / UERANSIM non toccati

Verificato con `pgrep -a open5gs`, `pgrep -a nr-gnb`, `pgrep -a nr-ue` prima e dopo Patch 5C e Patch 5D in questa sessione: stessi PID/processi attivi, nessun riavvio, nessuna modifica.

## `ogstun` / `uesimtun0`

Verificato con `ip addr show ogstun` / `ip addr show uesimtun0` prima e dopo Patch 5C e 5D in questa sessione: indirizzi IPv4/IPv6 invariati (`ogstun` 10.45.0.1/16, `uesimtun0` 10.45.0.2/24).

## Data plane UE→UPF

**Non testato direttamente in questo ciclo di patch frontend** (Patch 1-5D erano patch di UI/frontend, non di rete). Il runbook (`RUNBOOK_5G_LAB_PORTAL.md` §12) descrive come eseguire questo test quando necessario.

## Badge/freshness

Verificato in Patch 3 (introduzione vocabolario badge) e Patch 5 (screenshot di protocol_console.html con 3 sorgenti STALE + età, core_console.html con 10 NF, di cui 4 con badge freshness reale e 6 onestamente UNKNOWN, alarms.html con badge LIVE).

## Fallback WebSocket (Patch 5C/5D)

Verificato in questa sessione con script dedicati:
- `sparkEmpties: 3` (tutti e 3 gli sparkline mostrano `NO LIVE DATA` quando `history` è vuoto)
- `streamFlag: "SIMULATED · WS ONLINE · NO COMPATIBLE TELEMETRY"` (GpuRfRenderingEngineV19G)
- `kpiSourceFlag: "BASELINE · WS ONLINE · NO COMPATIBLE TELEMETRY"` (RealtimeTelemetryBusV19F)
- `kpiToneBaseline: 6` (tutti e 6 i KPI in tono neutro, non verde/giallo "salute")

## Auto-scroll (Patch 5C)

Verificato con `window.scrollY` misurato a 1s e 3s dal caricamento di `#sentinel-x-legacy`: **0/0** dopo il fix (prima del fix: 0 → ~6966 in ~2s).

## Canvas zero-size

Verificato su tutte e 4 le route Vite/React dopo Patch 5C e 5D: **0 canvas con `clientWidth` o `clientHeight` pari a 0**.

## Console/network errors residui

Solo quelli della Limitation #1 (`#live-ops`, CORS/404 su `/api/v16f/telemetry/fast`) — **conteggio invariato** tra pre-5C, post-5C e post-5D (9 errori console, 5 network fail), quindi nessun nuovo errore introdotto.

## Screenshot/check prodotti (path)

Directory: `/tmp/claude-1000/-home-debian-5g-lab-portal-spatial/88b5bccb-c7aa-4d17-a346-b31fe30610a1/scratchpad/spatial_shots/` (sessione Vite/React, Patch 5C/5D):
- `patch5c_sentinel-x-legacy_top.png`, `patch5c_telemetry_bus.png`, `patch5c_gpu_rf.png`, `patch5c_gpu_rf_waited.png`, `patch5c_orchestrator.png`
- `patch5c_<route>_top.png` per le 4 route (regressione)
- `patch5d_telemetry_bus.png`, `patch5d_gpu_rf.png`

**Nota**: questi screenshot risiedono in una directory di scratchpad temporanea legata alla sessione, non in un percorso persistente del progetto. Se si desidera conservarli a lungo termine, vanno copiati altrove esplicitamente (azione non eseguita in questa patch documentale, per non eccedere l'ambito autorizzato).

Per il portale statico, gli screenshot di Patch 4/5 sono stati generati e ispezionati durante quelle patch ma la loro posizione esatta su disco non è stata ri-verificata in questa sessione (Patch 5E) — riportati qui solo come evidenza descritta, non ri-confermata.

---

## Aggiornamento 2026-07-04 — Patch 7C, 7D, 8A, 8B, 8C

### Patch 7C — Enterprise Global Refitting

- 10 pagine statiche + 1 file Vite/React verificati via Playwright: controlli zoom/pan/fit/reset/fullscreen su diagramma O-RAN (Home), Multi-Site, Multi-RAT, Spatial Lab — screenshot e verifica DOM per ciascuno.
- Overflow `#sentinel-x-legacy` verificato **assente** a 1366×768 e 1440×900 dopo il fix `.rf18c-grid`/`.rf18c-two`/`.rf18c-grid3` (`scrollWidth === innerWidth`, prima del fix: overflow presente).
- WARN emerso durante test responsive di `signal_analyzer.html` a 1366×768 (canvas 0-height, label overlap O-RAN E2E) — documentato onestamente, non corretto in questa patch, risolto in Patch 7D.

### Patch 7D — Signal Analyzer Responsive & O-RAN E2E Refinement

- Risoluzioni testate: 1366×768, 1440×900, 1920×1080, 2560×1440 — **PASS** su tutte.
- Canvas `cvs-ray`/`packetCanvas`: **0 canvas a zero-size** dopo il fix (prima: 2 canvas a 0-height a 1366×768).
- 0 console/network errors introdotti.
- VSA Constellation fullscreen (fix Patch 7B) verificata **non regredita**.
- O-RAN E2E fullscreen verificato leggibile.
- Nessun servizio toccato (verificato via `pgrep`/`ip addr` invariati).

### Patch 8A — Vite/React Global Overflow Root Fix

- Risoluzioni testate: 1920×1080, 1440×900, 1366×768, 1024×768 — tutte **PASS** (`document.documentElement.scrollWidth === window.innerWidth`).
- Verificato con **dati reali dal backend 8090** (non mock): righe di log Open5GS fino a 259/255 caratteri confermate presenti nei pannelli "HTTP Bundle"/"WebSocket Snapshot", e confermate **scorrere internamente** al pannello (`pre.scrollWidth > pre.clientWidth`) invece di espandere la pagina.
- Route reali testate: `#live-ops`, `#sentinel-x`, `#sentinel-x-legacy`, `#instrument-lab` — tutte 0 console error, 0 network fail, 0 canvas zero-size, 0 overflow.
- Build (`npm run build`): **PASS**, 242 moduli, nessun errore TypeScript/Vite.
- Nessun servizio toccato (backend 8090/8000/8080 raggiungibili e invariati, nessun restart).

### Patch 8B — LiveOps 3D Mirrored Text Fix

- Testo waterfall ("RF WATERFALL / 5G NR SYNTH / PCAP TIMELINE") verificato **non speculare** in 2 istanti dell'orbita camera in cui il pannello era chiaramente inquadrato (t=10s, t=100s su una sessione continua), confermato via crop ingrandito pixel-per-pixel.
- Confronto diretto con lo stato pre-fix: crop dello screenshot originale (`vsa.png`) confermava testo chiaramente speculare/capovolto nello stesso tipo di inquadratura.
- Campionamento su 14 istanti totali lungo l'orbita: 0 console error, scena 3D sempre renderizzata, nessuna label nera o scomparsa in modo anomalo.
- Route reali testate: tutte PASS. Build: PASS.
- **Nota onesta**: verifica diretta dell'angolazione "esattamente da dietro" non ottenuta per limite di composizione/inquadratura camera (il pannello esce dal frame in quella fase dell'orbita indipendentemente dalla patch) — correttezza in quel caso basata sulla solidità della tecnica standard Three.js applicata (`scale.x=-1` su mesh fronte/retro), non su cattura diretta.

### Patch 8C — LiveOps 3D Label/HUD Collision Fix

- Test orbita camera completa: **120 secondi** (un ciclo completo, periodo orbita ≈114s), **120 campioni** a 1 misurazione al secondo.
- **Overlap label/HUD: 0 su 120 campioni** (verifica finale, con `TRIGGER_LEAD=48`).
- Iterazione di tuning intermedia documentata onestamente: con `TRIGGER_LEAD=20`, 1-2 campioni su 30 mostravano un overlap residuo di 72-156px² (pochi pixel al bordo) — chiuso aumentando l'anticipo di trigger.
- Label sempre visibile (0 frame con label invisibile su 120 campioni).
- 0 console error su tutti i campioni.
- Risoluzioni 1920×1080, 1440×900, 1366×768, 1024×768: tutte PASS.
- Non regressione Patch 8A: `scrollWidth<=innerWidth+2` confermato con dati reali attivi su tutte le 4 risoluzioni.
- Non regressione Patch 8B: testo waterfall confermato non speculare, canvas waterfall presente e renderizzato.
- Route reali testate: tutte PASS. Build: PASS.
- Nessun servizio toccato.

### Screenshot/check prodotti (Patch 7C-8C)

Directory: `/tmp/claude-1000/-home-debian-5g-lab-portal-spatial/88b5bccb-c7aa-4d17-a346-b31fe30610a1/scratchpad/spatial_shots/` (stessa directory di scratchpad temporanea di sessione già citata per Patch 5C/5D — stessa nota di non-persistenza si applica).

---

## Aggiornamento 2026-07-05 — Patch 8D (investigazione), Patch 8E (documentazione)

### Patch 8D — DATA_CONTRACT Discrepancy Investigation (solo read-only)

- Endpoint interrogati via `curl` (porta 8090): `/api/health` → 200 OK; `/api/v16f/health` → 200 OK; `/api/v16f/telemetry/fast` → 200 OK con payload JSON valido.
- WebSocket probe read-only (`ws://127.0.0.1:8090/ws/v16f/telemetry`): connessione aperta, 2 messaggi letti (handshake + snapshot), connessione chiusa — nessun comando inviato.
- Verifica CORS: header `access-control-allow-origin` presente per origin sia consentiti che non listati esplicitamente — confermato un secondo `CORSMiddleware` permissivo nel backend (sezione "STEP 8A TM DYNAMIC API" del codice backend, non correlata alla Patch 8A frontend).
- Route reali confermate via lettura sorgente: `#live-ops` (default), `#sentinel-x`, `#sentinel-x-legacy`, `#instrument-lab` — 4 totali, `App.tsx` confermato dead code (non importato da `main.jsx`).
- RF confermato **SIMULATED**: letto codice sorgente `telemetry_ultrafast_service.py`, funzione `ultrafast_rf(tick)` — generazione puramente `sin`/`cos`, nessuna dipendenza da hardware o Open5GS.
- Core NF states confermati **EVIDENCE-BASED**: letto codice sorgente, funzione `classify_smart()` — tail reale dei file di log Open5GS, non un check di processo.
- 0 network fail, 0 console error osservati durante l'intera investigazione.

### Patch 8E — DATA_CONTRACT Documentation Alignment

- Verifica grep post-modifica su tutti i file in `docs/release/`: `Patch 8D`, `Patch 8E`, `/api/v16f/telemetry/fast`, `/ws/v16f/telemetry`, `LiveOpsCockpitV16`, `SIMULATED`, `EVIDENCE-BASED`, `UX GAP`, `Patch 8F`, `NOT CLAIMED`, `PLANNED` — tutti presenti nei file pertinenti (vedi report finale Patch 8E per il dettaglio).
- Verifica assenza di claim falsi: nessuna occorrenza di `full 3GPP compliant`, `RF live integration completed`, `Sentinel Bridge implemented`, `zero limitations`.
- Verifica `find -newer` sui backup pre-8E: **nessun file di codice** (`.jsx/.tsx/.js/.ts/.css/.html`) modificato — solo i 6 file Markdown autorizzati.
- Nessun servizio riavviato, nessuna build eseguita (non necessaria per modifiche Markdown).

---

## Aggiornamento 2026-07-05 — Patch 9A/9B (design), Patch 9C (implementazione + activation)

### Patch 9A — RF Source Dual Mode Design
- `lsusb`: nessun VID:PID HackRF (`1d50:6089`)/bladeRF (`2cf0:5250`/`1d50:6066`) trovato.
- `hackrf_info`/`bladeRF-cli`: comando non trovato (non installati).
- `dpkg -l`/`pip list`: nessun pacchetto SDR (`hackrf`,`bladerf`,`soapysdr`,`gnuradio`,`rtl-sdr`) installato.
- Codice sorgente confermato: `ultrafast_rf(tick)` 100% sintetico (`sin`/`cos`).

### Patch 9C — implementazione (prima del restart)
- `python3 -m py_compile app/services/rf_source_provider.py` → **PASS**.
- `python3 -m py_compile app/services/telemetry_ultrafast_service.py` → **PASS**.
- `grep -RniE "tx|transmit|start_tx|sync_tx|hackrf_start_tx|bladerf_sync_tx" rf_source_provider.py` → 3 occorrenze, tutte in commenti che dichiarano il divieto (nessuna funzione TX reale).
- Verifica funzionale offline (import isolato del modulo `rf_source_provider`, non il servizio in esecuzione):
  - Config default (nessuna env var) → `SimulatedRfProvider`; `sinr`/`bler`/`throughputMbps` top-level == valori diretti di `legacy_rf_fn`; `legacy_synthetic.sinr == rf.sinr` → True.
  - `RF_SDR_ENABLE=1`+`RF_SOURCE_MODE=sdr_rx`+`RF_SDR_DEVICE=hackrf`, nessun hardware → `UnavailableRfProvider`, `source_mode="unavailable"`, numeri legacy comunque popolati (fallback).
  - `RF_SOURCE_MODE=auto`, nessun hardware → `SimulatedRfProvider` silenzioso.
  - `detect_sdr_devices()` diretta → `{"found": False, "device": "none", "reason": "no supported SDR device found in lsusb"}`.
- 4 route reali verificate PASS (backend ancora sul codice precedente in questa fase, nessuna disruzione da creazione/modifica file).

### Patch 9C — Activation (restart backend 8090)
- Pre-restart: PID `291968`, health `{"status":"ok","version":"V16F-ULTRAFAST-WS-NO-SCAN",...}`.
- Post-restart: PID `743558`, health identico, log restart pulito (nessun traceback).
- REST `/api/v16f/telemetry/fast` (post-restart): `rf.source_mode="simulated"`, `rf.provenance="SIMULATED"`, `rf.source_device="none"`, `rf.nr_phy_decoded=false`; campi legacy presenti (`rsrp=-92.0, rsrq=-9.6, sinr=22.0, bler=1.5, throughputMbps=1800, activeUes=1200`); `legacy_synthetic.sinr==rf.sinr` → True; `legacy_synthetic.bler==rf.bler` → True; `legacy_synthetic.throughputMbps==rf.throughputMbps` → True; `metrics` tutti null/vuoti; `limitations` con 2 voci esplicite.
- WebSocket `/ws/v16f/telemetry` (post-restart, probe read-only 2 messaggi): handshake `mode:"ws-accepted"` senza `rf`; snapshot successivo `mode:"backend-smart-live-readonly"`, `rf.source_mode:"simulated"`, `rf.provenance:"SIMULATED"`, `legacy_synthetic` presente — nessun comando mutante inviato.
- 4 route reali (post-restart): `#live-ops`/`#sentinel-x`/`#sentinel-x-legacy`/`#instrument-lab` tutte 0 overflow/0 console error/0 network fail/0 canvas zero-size.
- Non regressione `#live-ops` (post-restart): 8 canvas presenti, overlap label/HUD=0, label `LEO/NTN RELAY` visibile, KPI popolati (`SINR 28.8 dB`, `BLER 0.73%`, `TP 3539 Mbps`), nessuna dicitura `RF LIVE`/`LIVE RF` nel testo pagina, 0 console error.
- Open5GS/UERANSIM: 10 processi Open5GS, 2 `nr-gnb`, 3 `nr-ue` — invariati pre/post restart.
- Backend 8000/portale statico 8080/Vite 5177: invariati, nessun restart.

### Patch 9D — SDR RX Snapshot Implementation Design (solo design/read-only)

- **Nessun test eseguito** in questa patch — per costruzione: solo lettura di codice (`rf_source_provider.py` ri-confermato invariato da Patch 9C) e documentazione esistente, nessuna interrogazione hardware, nessuna installazione libreria, nessuna variabile d'ambiente cambiata, nessun servizio riavviato.
- I risultati di detection SDR (nessun HackRF/bladeRF presente, nessun tool/libreria SDR installata) sono quelli già raccolti e verificati in Patch 9A — non ripetuti in questa patch per vincolo esplicito ("non fare `lsusb` se non strettamente necessario; assumere quanto già rilevato").
- Il design prodotto (architettura worker/cache, scelta SoapySDR, payload futuro, error handling, RX-only guardrails, test plan) **non è stato eseguito né verificato a runtime** — è una specifica per una futura Patch 9E, da validare solo quando hardware SDR fisico sarà disponibile.

---

## Aggiornamento 2026-07-05 — Patch 10C (Activation), chiusura documentale dopo ripresa sessione

Sessione di sola chiusura documentale: nessun codice modificato, nessun restart eseguito in questa sessione, nessuna discovery hardware, nessuna chiamata SCPI/VISA/vendor. Le verifiche sotto sono tutte read-only (`ss`, `ps`, `curl`), eseguite per confermare quanto già segnalato come "stato servizi già verificato" all'apertura di questa sessione.

### Stato servizi (verificato read-only in questa sessione)

| Servizio | Verifica | Esito |
|---|---|---|
| Vite 5177 | `ss -ltnp` + `curl` | LISTEN, 200 |
| Backend 8000 | `ss -ltnp` | LISTEN |
| Statico 8080 | `ss -ltnp` + `curl` | LISTEN, 200 |
| Backend 8090 | `ss -ltnp` + `curl /api/health` | LISTEN (PID 785527), `{"status":"ok","service":"5g-spatial-secure-api","version":"0.1.0-rc1","security_mode":"baseline"}` |

### PID backend 8090 — cronologia dichiarata vs osservata

| Momento | PID | Fonte |
|---|---|---|
| Pre-restart controllato (Patch 10C Activation) | `743558` | dichiarato nel report di attivazione |
| Post-restart controllato (Patch 10C Activation) | `781718` | dichiarato nel report di attivazione |
| Osservato alla ripresa sessione (questa chiusura documentale) | `785527` | verificato in questa sessione via `ss -ltnp` + `ps -p` |

**Nota onesta**: `781718` non risulta più un processo attivo (verificato: `ps -p 781718` non restituisce nulla); il PID realmente in ascolto sulla 8090 è `785527`, stesso comando esatto (`.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8090`), stesso binding (`127.0.0.1:8090`), uptime ~685s (~11m26s) al momento della verifica. La discrepanza tra PID dichiarato (`781718`) e PID osservato (`785527`) **non è stata investigata** in questa sessione — fuori ambito per vincolo esplicito (nessun restart, nessuna discovery). Si registra il fatto osservato, senza dichiarare una causa.

### Payload `instrument` — verificato read-only (`GET /api/v16f/telemetry/fast`)

```json
{
  "enabled": false,
  "source_mode": "instrument_disabled",
  "provenance": "NOT_ENABLED",
  "readonly": true,
  "vendor": "none",
  "family": "none",
  "resource": null,
  "transport": "none",
  "device_status": "disabled",
  "cache_status": "not_applicable",
  "snapshot_age_ms": null,
  "metrics": {},
  "safety_policy": {
    "readonly": true,
    "allow_configuration_writes": false,
    "allow_rf_output_control": false
  },
  "limitations": [
    "RF_INSTRUMENT_ENABLE=0: professional instrument provider disabled by default",
    "No VISA/SCPI discovery performed in Patch 10C",
    "No instrument measurement performed in Patch 10C"
  ],
  "warnings": []
}
```

Confermato campo-per-campo conforme ai dati attesi per la chiusura di Patch 10C: `enabled=false`, `source_mode=instrument_disabled`, `provenance=NOT_ENABLED`, `readonly=true`, `device_status=disabled`, `metrics={}`, `allow_configuration_writes=false`, `allow_rf_output_control=false`.

### Vincoli rispettati in questa sessione (verificato)

- Nessuna modifica di codice (solo Markdown in `docs/release/`).
- Nessun restart eseguito in questa sessione (il restart controllato di Patch 10C è un evento **precedente**, dichiarato nel report; questa sessione lo documenta soltanto).
- Nessuna discovery hardware, nessuna chiamata SCPI/VISA, nessun import vendor.
- Open5GS/UERANSIM, routing/iptables/interfacce: non toccati, non interrogati.
- Patch 10D: confermata **PLANNED**, nessuna implementazione introdotta.

---

## Aggiornamento 2026-07-05 — Patch 10D-B (Instrument Read-Only Provider Implementation)

Implementazione codice backend additive-only, verificata **solo offline** (nessun restart, nessuna attivazione reale, nessun hardware). File toccato: `backend/app/services/instrument_source_provider.py`. Backup: `instrument_source_provider.py.pre10d-b.bak`.

### 7.1 — `py_compile`

| File | Esito |
|---|---|
| `instrument_source_provider.py` | **PASS** |
| `telemetry_ultrafast_service.py` (non modificato) | **PASS** |

### 7.2 — Import isolato

46 nuovi moduli caricati dall'import del modulo; **0** moduli `pyvisa`/`RsInstrument`/`usb`/`vxi11`/`zeroconf` tra questi — **PASS**.

### 7.3 — Default disabled (ambiente pulito, `RF_INSTRUMENT_ENABLE` assente)

`provider=DisabledInstrumentProvider`, `enabled=false`, `source_mode=instrument_disabled`, `provenance=NOT_ENABLED`, `device_status=disabled`, `metrics={}` — **PASS**.

### 7.4 — Enable dry-run con resource/allowlist validi

Config: `RF_INSTRUMENT_ENABLE=1`, `RF_INSTRUMENT_DRY_RUN=1`, `RF_INSTRUMENT_VENDOR=rohde-schwarz`, `RF_INSTRUMENT_FAMILY=spectrum_analyzer`, `RF_INSTRUMENT_RESOURCE=TCPIP0::192.0.2.10::inst0::INSTR` (IP documentation-safe TEST-NET-1, non un IP reale), `RF_INSTRUMENT_ALLOWLIST_RESOURCE=TCPIP0::192.0.2.10::inst0::INSTR`.

Atteso e confermato: `provider=ProfessionalInstrumentReadOnlyProvider`, `enabled=true`, `source_mode=instrument_read_only_dry_run`, `provenance=DRY_RUN`, `readonly=true`, `device_status=dry_run_not_connected`, `metrics={}`, `dry_run=true`, `resource_policy.resource_allowed=true`, `command_policy.executed_commands=0` — **PASS**.

### 7.5 — Enable dry-run SENZA allowlist

Config: `RF_INSTRUMENT_ENABLE=1`, `RF_INSTRUMENT_DRY_RUN=1`, `RF_INSTRUMENT_RESOURCE` impostata, `RF_INSTRUMENT_ALLOWLIST_RESOURCE=""`.

Atteso e confermato: `provider=UnavailableInstrumentProvider`, `source_mode=instrument_unavailable`, `device_status=blocked_by_resource_policy`, `metrics={}` — **PASS**.

### 7.6 — Enable non-dry-run

Config: `RF_INSTRUMENT_ENABLE=1`, `RF_INSTRUMENT_DRY_RUN=0`.

Atteso e confermato: `provider=UnavailableInstrumentProvider`, `source_mode=instrument_unavailable`, `device_status=activation_not_authorized`, `metrics={}` — **PASS**.

### 7.7 — Grep sicurezza

Pattern cercati: `ResourceManager(`, `list_resources(`, `open_resource(`, `.query(`, `.write(`, `socket.connect`, `subprocess`. Risultato: **4 occorrenze totali**, tutte in commenti/docstring che dichiarano esplicitamente l'assenza di queste chiamate (es. `"NEVER creates a VISA ResourceManager, NEVER calls list_resources()/open_resource()/.query()/.write()"`); **0 occorrenze in codice operativo eseguibile**. `.query(`, `.write(`, `socket.connect`, `subprocess` non compaiono nemmeno in commento — **PASS**.

### Verifica runtime (nessun restart)

- `ss -ltnp` su 5177/8000/8080/8090: tutte LISTEN, PID 8090 invariato (`785527`) prima/durante/dopo l'implementazione.
- Payload live (`GET /api/v16f/telemetry/fast`, backend non riavviato) confermato **ancora sullo schema Patch 10C** — nessuna chiave `schema_version`/`dry_run`/`provider`/`capabilities`/`dependencies`/`resource_policy`/`command_policy` presente nella risposta live — prova diretta che il codice di Patch 10D-B non è attivo a runtime.
- Open5GS: 10 processi attivi (invariato). `ogstun` 10.45.0.1/16, `uesimtun0` 10.45.0.2/24 (invariati).

### Vincoli rispettati (verificato)

- Nessuna installazione pacchetti (`pip`/`apt` mai invocati).
- Nessuna chiamata `pyvisa.ResourceManager()`, `list_resources()`, `open_resource()`, `.query()`, `.write()`.
- Nessun accesso USBTMC/seriale/TCP verso strumenti.
- Nessun comando SCPI, nessun preset/reset, nessun output RF.
- Nessuna modifica ambiente permanente (solo variabili passate inline ai singoli processi di test tramite `env -i`).
- Nessun restart del backend 8090.
- Nessun test con hardware reale.

---

## Aggiornamento 2026-07-05 — Patch 10D-C (Activation Restart + Portal View Smoke Test) e Checkpoint

### Restart controllato

| Momento | PID | Verifica |
|---|---|---|
| Prima | `785527` | comando/cwd confermati via `/proc` prima dello stop |
| Dopo | `799185` | stesso comando esatto, stessa cwd, nessun duplicato (`pgrep -af` una sola riga) |

`/api/health` post-restart: 200 OK, `uptime_s` da 7.21 a 806.23 al momento del checkpoint (coerente col solo trascorrere del tempo, nessun ulteriore restart).

### Payload `instrument` post-restart (REST + WS)

Confermato identico su entrambi i canali, ora con i campi additive-only di Patch 10D-B popolati per la prima volta a runtime: `schema_version=instrument.v10d-b`, `dry_run=true`, `provider=disabled`, `capabilities` (tutte `false`), `dependencies={"pyvisa":"not_checked","vendor_backend":"not_checked"}`, `resource_policy.resource_allowed=false`, `command_policy.executed_commands=0` — mantenendo `enabled=false`, `source_mode=instrument_disabled`, `provenance=NOT_ENABLED`, `device_status=disabled`, `metrics={}`.

### Smoke test portale (HTTP-level, read-only)

| URL | Esito |
|---|---|
| `http://127.0.0.1:8080/frontend/index.html` | 200 |
| `http://127.0.0.1:5177/#live-ops` | 200 |
| `http://127.0.0.1:5177/#instrument-lab` | 200 |
| `http://127.0.0.1:5177/#sentinel-x` | 200 |
| `http://127.0.0.1:5177/#sentinel-x-legacy` | 200 |

**Limite dichiarato**: le route Vite sono hash-based (SPA) — `curl` non può verificare console error/network fail/canvas zero-size/overflow per singola route (il fragment non arriva al server). Verifica visiva completa richiederebbe Playwright/Chromium, **non installati** in questo ambiente e non installabili in questo ciclo (vincolo esplicito). Confermato con `find`: `playwright-core` presente in `node_modules`, ma senza binari browser scaricati.

### Checkpoint 2026-07-05 — verifiche read-only ripetute

Stato servizi, health 8090, 5 URL portale: tutti riconfermati invariati/200 in questa sessione di checkpoint. Open5GS (10 processi), `ogstun`/`uesimtun0` (indirizzi invariati). Nessuna azione oltre alla verifica e alla documentazione.
