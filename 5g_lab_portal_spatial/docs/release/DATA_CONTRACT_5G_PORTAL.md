# Data Contract — 5G Lab Portal

Documenta solo gli endpoint realmente osservati/implementati durante Patch 1-5D. Nessun endpoint qui è ipotetico.

## Nota — Patch 7C/7D/8A/8B/8C (2026-07-04)

Nessuna di queste cinque patch ha modificato il data contract: nessun endpoint nuovo, nessun payload nuovo, nessun cambio di schema WebSocket, nessuna modifica alla RF provenance. Tutte le modifiche di quell'aggiornamento sono limitate a UI/layout/CSS/documentazione (vedi `PATCH_HISTORY.md` per il dettaglio file-per-file).

**Discrepanza segnalata in quell'aggiornamento, ora investigata e riallineata (Patch 8D/8E, 2026-07-05)**: la sezione "Portale Vite/React — backend telemetria, porta 8090" più sotto in questo documento era **stale** per tutto ciò che riguarda `#live-ops`/`LiveOpsCockpitV16` — descriveva un endpoint/WebSocket/schema diverso da quello realmente consumato da quella route. Root cause confermata leggendo il codice sorgente backend (Patch 8D, investigazione read-only): il backend ha evoluto un secondo router (`v16f_ultrafast_router.py`, endpoint `/api/v16f/*` e WS `/ws/v16f/telemetry`) in un momento successivo a quando questa sezione era stata scritta (Patch 5C/5D), senza che la documentazione venisse aggiornata di conseguenza. La sezione sottostante è stata riscritta per riflettere lo stato reale osservato il 2026-07-05. Nessun codice è stato modificato per produrre questo allineamento — solo lettura di codice sorgente e probe read-only (`curl`, WebSocket read-only).

---

## Frontend runtime reale (confermato via lettura codice sorgente, Patch 8D)

```text
index.html → src/main.jsx → src/App.jsx
```

**`src/App.tsx` esiste su disco ma non è l'entrypoint reale**: `index.html` carica esclusivamente `<script src="/src/main.jsx">`, che importa `App` da `./App.jsx` (non da `./App.tsx`). Di conseguenza `src/App.tsx` — inclusa la sua whitelist interna di ~58 nomi di route (`VALID_ROUTE_VALUES`) — è **codice morto/non referenziato dal runtime attuale**. Qualunque riferimento futuro a quelle ~58 route in altra documentazione va considerato storico/non operativo.

Le route hash realmente gestite da `src/App.jsx` sono solo 4:

| Route | Componente reale | Stato |
|---|---|---|
| `#live-ops` | `LiveOpsCockpitV16` | default/fallback — anche per qualunque hash non riconosciuto |
| `#sentinel-x` | `SentinelXMissionWorkspaceV19N` | route reale |
| `#sentinel-x-legacy` | `SentinelXMasterShellV18A` | route reale |
| `#instrument-lab` | `InstrumentLabPageV17F` | route reale |

Qualunque hash diverso da questi 3 (incluso vuoto, o uno qualunque dei nomi in `App.tsx`) ricade su `#live-ops`/`LiveOpsCockpitV16`.

---

## Portale statico — backend FastAPI, porta 8000

### `GET /api/health`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: tutte le pagine del portale statico (check di raggiungibilità backend)
- Payload atteso: stato sintetico del servizio backend
- Freshness/source: check dal vivo ad ogni chiamata (non basato su file di log)
- Stato attuale: implementato e in uso da Patch 1 in avanti
- Stato dato: **LIVE** (è un check attivo, non un default)

### `GET /api/lab/status`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: `index.html` (badge core/RAN), `core_console.html`
- Payload atteso: stato PROCESSO (vivo/morto) per ciascuna NF Open5GS + UERANSIM
- Campi principali: mappa `processes` con chiave = nome NF, valore = stato up/down
- Freshness/source: check di processo dal vivo, **non** derivato da log — per contratto, questo campo non deve mai essere sovrascritto da uno stato "log stale"
- Stato attuale: implementato, usato da Patch 3 per il badge `core-ran-badge`
- Stato dato: **LIVE** (o **DOWN** se il processo non risponde) — mai STALE, perché non deriva da file

### `GET /api/core/status`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: dashboard/console core
- Payload atteso: stato aggregato Core (NF summary)
- Stato attuale: presente, non oggetto di modifiche dirette in Patch 1-5 (solo consumato)
- Stato dato: **LIVE** (check di processo) — vedere nota sopra su non confondere con freshness dei log

### `GET /api/core/events`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: `core_console.html` (Patch 3, Patch 5 — Core NF Summary panel)
- Payload atteso (dopo Patch 2): oggetto con `sources` (lista file sorgente con `source_file`, `source_type`, `mtime`, `age_seconds`) e `freshness` a livello top
- Campi principali: `sources[].source_type`, `sources[].age_seconds`, `freshness.state`
- Freshness/source: calcolato da `classify_source_type()` + `freshness_info()`, soglia `FRESHNESS_LIVE_THRESHOLD_S` (default 180s, configurabile via env)
- Stato attuale: rientrato in Patch 2 (backend) e Patch 3/5 (frontend, badge + NF table)
- Stato dato: **LIVE** se `age_seconds` < soglia, **STALE** altrimenti — mai **DOWN** solo per questo campo

### `GET /api/protocols/events`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: `protocol_console.html` (Patch 3, Patch 5 — Protocol Session Summary, timeline NGAP/NAS)
- Payload atteso: stessa struttura `sources`/`freshness` di `/api/core/events`, più eventi grezzi (righe log NAS/NGAP/SBI/PFCP/GTP-U)
- Campi principali: `events[]` (righe testuali), `sources[]`, `freshness`
- Stato attuale: verificato in Patch 5 — al momento del test mostrava 14 eventi, 3 sorgenti, tutte STALE, 8/8 step della timeline in `NO EVIDENCE` (il log-tail era traffico SBI/subscription, non NAS/NGAP reale)
- Stato dato: **STALE** (confermato via badge), timeline **EVIDENCE-BASED quando disponibile, altrimenti NO EVIDENCE** — mai inventato

### `GET /api/alarms`
- Protocollo: HTTP/REST
- Porta: 8000
- Consumer: `alarms.html` (Patch 3, Patch 5 — Alarm Correlation Summary)
- Payload atteso: `{ alarms: [{code, text, severity}, ...] }`
- Campi principali: `alarms[].severity` (critical/major/info)
- Freshness/source: nessun campo di freshness proprio — è un check dal vivo ad ogni chiamata; una risposta valida (anche con 0 allarmi) è trattata come LIVE, non EVIDENCE-BASED nel senso storico
- Stato attuale: verificato in Patch 5 — Total=1, Critical=0, Major=0, Info=1
- Stato dato: **LIVE** se la chiamata ha successo, **UNKNOWN/DEGRADED** se l'endpoint non risponde (mai "nessun allarme" == garanzia assoluta, testo esplicito aggiunto in Patch 5)

---

## Portale Vite/React — backend telemetria, porta 8090

**Aggiornato 2026-07-05 (Patch 8D/8E)**: questa sezione descrive due canali distinti che coesistono sullo stesso backend: il canale **v16f** (nuovo, usato da `#live-ops`) e il canale **legacy** `/ws/telemetry` (più vecchio, usato da `#sentinel-x`/`#sentinel-x-legacy`). Non fonderli: hanno schema e consumer diversi.

### Endpoint osservati (backend 8090)

| Endpoint | Stato osservato (2026-07-05) | Note |
|---|---|---|
| `GET /api/health` | **200 OK** | Health generico del backend 8090 (`5g-spatial-secure-api`) |
| `GET /api/v16f/health` | **200 OK** | `{"status":"ok","version":"V16F-ULTRAFAST-WS-NO-SCAN","mode":"read-only-mounted-router-ultrafast"}` |
| `GET /api/v16f/telemetry/fast` | **200 OK** | Usato da `LiveOpsCockpitV16` (route `#live-ops`) — vedi payload sotto |
| `ws://127.0.0.1:8090/ws/v16f/telemetry` | **ACTIVE** | WebSocket usato da `#live-ops`, confermato via probe read-only |
| `ws://127.0.0.1:8090/ws/telemetry` | **PRESENT / legacy-compatible** | Ancora presente nel codice backend, ma **non** è il canale consumato da `#live-ops` — vedi sotto |

Nessun endpoint qui è dichiarato operativo senza essere stato verificato direttamente in questa sessione (Patch 8D, 2026-07-05).

### `GET /api/v16f/telemetry/fast` — canale reale di `#live-ops`
- Protocollo: HTTP/REST · Porta: 8090
- Consumer: `LiveOpsCockpitV16` (route `#live-ops`, tramite `services/liveOpsServiceV16.js` → `fetchLiveOpsBundleV16()`)
- Stato osservato: **200 OK**, payload JSON valido (confermato con `curl` diretto, non un'ipotesi)
- Schema reale osservato:
  ```json
  {
    "timestamp": "...", "version": "V16G-SMART-LOG-CLASSIFIER",
    "mode": "backend-smart-live-readonly", "tick": 0,
    "core": { "mode": "v16g-smart-open5gs-classifier", "source": "smart-tail-score-no-rglob", "nfs": { "amf": {"state": "...", "score": 0, "tail": [...] }, ... } },
    "ueransim": { "mode": "not-scanned-in-websocket", "reason": "kept out of realtime loop for stability", "logs": [] },
    "rf": { "rsrp": ..., "rsrq": ..., "sinr": ..., "bler": ..., "throughputMbps": ..., "activeUes": ... },
    "pcap": { "mode": "v16g-smart-pcap-synthetic", "timeline": [...] },
    "security_boundary": { "real_jamming": false, "rogue_cell_operation": false, "ue_compromise": false, "mode": "defensive-observability" }
  }
  ```
- Provenienza campo per campo:
  - `core`/`core.nfs`: **derivato da tail reale** degli ultimi byte dei file di log Open5GS (`~/lab/open5gs-d12-curl77/.../var/log/open5gs/{amf,smf,upf,...}.log`), classificato tramite match di token positivi/attenzione/stop predefiniti (funzione `classify_smart()`, backend `telemetry_ultrafast_service.py`). **Non** è un check di processo (`pgrep`) — è "log-evidence-based", non "process-live-based".
  - `ueransim`: placeholder dichiarato esplicitamente non scansionato (`"not-scanned-in-websocket"`, `logs: []`) — onesto, non fabbricato.
  - `rf` (rsrp/rsrq/sinr/bler/throughputMbps/activeUes): **interamente sintetico**, generato da funzioni `sin`/`cos` di un contatore interno (`tick`), nessuna lettura hardware/SDR, nessuna derivazione da Open5GS. Il payload **non** riporta un flag esplicito "simulated" per questo campo (a differenza di `pcap.mode`).
  - `pcap.timeline`: **sintetico**, una lista fissa di messaggi di call-flow tipici con timestamp calcolati, non una cattura PCAP reale — il payload lo dichiara esplicitamente (`"mode": "v16g-smart-pcap-synthetic"`).
  - `security_boundary`: metadato statico che descrive il perimetro operativo read-only del backend, non un dato di telemetria.
- Stato dato: **misto** — `core` = EVIDENCE-BASED, `ueransim` = NO EVIDENCE/PLACEHOLDER, `rf` = SIMULATED, `pcap` = SIMULATED (auto-dichiarato).
- Known issue: sì — vedi "KPI provenance gap" più sotto e `KNOWN_LIMITATIONS.md`.

### `ws://127.0.0.1:8090/ws/v16f/telemetry` — WebSocket reale di `#live-ops`
- Protocollo: WebSocket · Porta: 8090
- Consumer: `LiveOpsCockpitV16` tramite `hooks/useLiveTelemetryWsV16.js`
- Comportamento osservato (probe read-only diretto, 2026-07-05): handshake iniziale, poi un messaggio ogni ~1.2s.
- Messaggio di handshake:
  ```json
  {"version": "V16F-ULTRAFAST-WS-NO-SCAN", "mode": "ws-accepted", "message": "handshake-ok", "tick": -1, "security_boundary": {...}}
  ```
- Messaggi successivi: stesso schema del payload REST sopra (`timestamp/version/mode/tick/core/ueransim/rf/pcap/security_boundary`).
- Canale strettamente read-only lato client: nessun comando viene mai inviato dal frontend al backend su questo socket.
- Stato dato: come sopra (misto EVIDENCE-BASED/SIMULATED/PLACEHOLDER a seconda del campo).

### `ws://127.0.0.1:8090/ws/telemetry` — canale legacy/alternativo (non usato da `#live-ops`)
- Protocollo: WebSocket · Porta: 8090
- Consumer reale: `RealtimeTelemetryBusV19F.jsx`, `GpuRfRenderingEngineV19G.jsx`, `EnterpriseSceneOrchestratorV19E.jsx`, `TacticalCommandConsoleV19J.jsx` (sotto le route `#sentinel-x`/`#sentinel-x-legacy`) — **non** `LiveOpsCockpitV16`/`#live-ops`.
- Payload atteso dal frontend consumer: `{ rf: {...}, core: {...}, tick, version }`
- Payload realmente osservato (letto da codice sorgente backend, funzione `synth_vsa_payload()` + wrapper WS): schema base `{timestamp, profile, kpi, state, beam}` (interamente sintetico, stessa logica `sin`/`cos`), **più un campo aggiuntivo `core`** (`schema_version: "v2-core-additive"`) — lo stesso `core` evidence-based descritto sopra, aggiunto in un momento successivo alla stesura originale di questo documento.
- Disallineamento di schema residuo: nessuna chiave `rf`/`version` top-level nel formato atteso dal consumer originale — il backend continua a usare `profile`/`kpi`/`state`/`beam` più `core` additivo. Non risolto, non nel perimetro di Patch 8D/8E (nessuna modifica al backend autorizzata).
- Stato attuale: WS si apre correttamente; i componenti consumer (`RealtimeTelemetryBusV19F` ecc.) mostrano badge onesti (`NO LIVE DATA`, `BASELINE · WS ONLINE · NO COMPATIBLE TELEMETRY`) per i campi che non riconoscono — pattern introdotto in Patch 5C, invariato.
- Stato dato: **BASELINE/SIMULATED** per i consumer che leggono `profile/kpi/state/beam`; il campo `core` additivo (se letto) sarebbe EVIDENCE-BASED, ma non risulta consumato dai componenti sopra elencati.
- Non è il canale principale di alcuna route: va trattato come legacy/alternate channel, non come il contratto dati di `#live-ops`.

---

## Provenienza dati — tabella riassuntiva (backend 8090, canale v16f)

| Campo | Provenienza | Stato |
|---|---|---|
| `core.nfs` | Tail reale dei log Open5GS + classificatore a token | **EVIDENCE-BASED** (non process-alive check) |
| `ueransim` | Non scansionato, placeholder dichiarato | **NO EVIDENCE / PLACEHOLDER** |
| `rf.rsrp`/`rf.sinr`/`rf.bler`/`rf.throughputMbps` | Funzione sintetica (`sin`/`cos` di un contatore) | **SIMULATED** (nessun flag esplicito nel payload) |
| `pcap.timeline` | Generatore sintetico a lista fissa | **SIMULATED** (auto-dichiarato via `mode`) |
| `security_boundary` | Metadato statico del backend | **READ-ONLY CONTEXT**, non telemetria |

Chiarimenti espliciti:
- `core` **non** è un check di processo (`pgrep`/equivalente) — è basato su evidenza di log, quindi più vicino a "STALE se il log non si aggiorna" che a "DOWN accertato".
- `rf` **non** è un feed SDR/HackRF/bladeRF live e **non** è derivato da Open5GS — RF status per `#live-ops`: **SIMULATED**. Nessun feed RF live è consumato da `LiveOpsCockpitV16` nel percorso dati osservato.
- `pcap` **non** è una cattura PCAP reale.
- Nessun claim di RF live esiste nel codice sorgente o nell'interfaccia di `#live-ops`.

## KPI provenance gap su `#live-ops` (Patch 8D, confermato)

`LiveOpsCockpitV16` mostra i valori derivati da `core.nfs` (stati NF, EVIDENCE-BASED) e i valori derivati da `rf` (SINR/BLER/Throughput, SIMULATED) **nello stesso riquadro visivo** ("5GC Live"), **senza badge esplicito** che distingua le due provenienze. Il meccanismo di gating LIVE/simulato esiste altrove nel codebase (`PORTAL_MODE`/`isLiveMode()` in `services/apiConfig.js`) ma non è importato né usato da questo componente o dai suoi hook.

- Classificazione: **UX GAP** + **DOCUMENTATION GAP** (non un bug funzionale — nulla si rompe, nessun dato è tecnicamente falso, manca solo l'etichetta di provenienza).
- Severità: **MEDIUM**.
- Rischio: in un contesto demo enterprise, un osservatore potrebbe ragionevolmente scambiare SINR/BLER/Throughput sintetici per misure derivate da Open5GS, dato l'accostamento visivo agli stati NF realmente evidence-based.
- Patch futura consigliata (non applicata qui): **Patch 8F — LiveOps Provenance Badge UI** — solo se ritenuta ancora necessaria al momento dell'autorizzazione.

---

## Riepilogo stato dati per endpoint

| Endpoint | Porta | Stato osservato |
|---|---|---|
| `/api/health` (8000) | 8000 | LIVE |
| `/api/lab/status` | 8000 | LIVE/DOWN (mai STALE) |
| `/api/core/status` | 8000 | LIVE |
| `/api/core/events` | 8000 | LIVE/STALE (per sorgente) |
| `/api/protocols/events` | 8000 | STALE (osservato in Patch 5) |
| `/api/alarms` | 8000 | LIVE/UNKNOWN |
| `/api/health` (8090) | 8090 | LIVE (200 OK, check attivo) |
| `/api/v16f/health` (8090) | 8090 | LIVE (200 OK, check attivo) |
| `/api/v16f/telemetry/fast` (8090) | 8090 | **misto**: core=EVIDENCE-BASED, ueransim=NO EVIDENCE, rf=SIMULATED, pcap=SIMULATED |
| `ws://.../ws/v16f/telemetry` (8090) | 8090 | ACTIVE — stesso stato misto del REST equivalente |
| `ws://.../ws/telemetry` (8090, legacy) | 8090 | BASELINE/SIMULATED per i consumer `#sentinel-x`/`#sentinel-x-legacy` (schema `profile/kpi/state/beam` ancora non allineato ai loro attese originali) |

### CORS — stato osservato 2026-07-05

Nessun blocco CORS osservato durante Patch 8D per `/api/v16f/telemetry/fast` né per il WebSocket `/ws/v16f/telemetry` (0 network fail su QA manuale di 120s e su probe diretti). Il backend registra **due** `CORSMiddleware`: uno restrittivo (solo `127.0.0.1:5177`/`localhost:5177`), un secondo — aggiunto in una milestone di sviluppo backend precedente e indipendente da questo ciclo di patch frontend — con `allow_origins` che include `"*"`. Il claim precedente "bloccato da CORS" per questo endpoint è **stale** e va considerato superato per il percorso qui documentato. Questo **non** significa che ogni possibile problema CORS del sistema sia risolto in modo definitivo — è una conferma limitata a quanto osservato per `/api/v16f/*` e `#live-ops` in questa sessione.

---

## Patch 9C — RF Source Provider Backend Skeleton (2026-07-05)

Introdotto un provider RF dual-mode dietro il campo `rf` di `/api/v16f/telemetry/fast` e `ws://.../ws/v16f/telemetry`. **Comportamento di default invariato**: senza configurazione esplicita, il payload resta identico a quanto documentato sopra (`rf` = SIMULATED). Questa patch **non** implementa acquisizione IQ reale, **non** usa HackRF/bladeRF, **non** dichiara RF live.

### Schema RF aggiornato (osservato dopo restart backend 8090, verificato con dati reali)

```json
{
  "rf": {
    "rsrp": -92.0,
    "rsrq": -9.6,
    "sinr": 22.0,
    "bler": 1.5,
    "throughputMbps": 1800,
    "activeUes": 1200,
    "source_mode": "simulated",
    "source_device": "none",
    "source_label": "SIMULATED RF",
    "provenance": "SIMULATED",
    "nr_phy_decoded": false,
    "nr_phy_decoded_reason": "not-implemented",
    "legacy_synthetic": {
      "rsrp": -92.0, "rsrq": -9.6, "sinr": 22.0, "bler": 1.5,
      "throughputMbps": 1800, "activeUes": 1200
    },
    "metrics": {
      "center_freq_hz": null, "sample_rate_sps": null, "peak_freq_hz": null,
      "peak_power_dbfs": null, "noise_floor_dbfs": null, "occupied_bw_hz": null,
      "waterfall": []
    },
    "limitations": [
      "No NR PHY decoder present — BLER/SINR/RSRP/MCS/EVM/CellID/SSB not derivable from raw RX",
      "source_mode=simulated: values are procedurally generated, not derived from RF hardware"
    ]
  }
}
```

Chiarimenti:
- I 6 campi legacy top-level (`rsrp/rsrq/sinr/bler/throughputMbps/activeUes`) **restano sintetici** — nessun cambiamento nel valore o nella provenienza rispetto a prima di Patch 9C. `LiveOpsCockpitV16` continua a leggerli senza modifiche.
- `legacy_synthetic` duplica esplicitamente la stessa fonte dei campi top-level — verificato uguale campo-per-campo dopo il restart (`legacy_synthetic.sinr == rf.sinr`, ecc.).
- `metrics` è lo spazio predisposto per un futuro SDR RX reale (Patch 9D) — in questa patch è sempre `null`/vuoto.
- `nr_phy_decoded:false` e `nr_phy_decoded_reason:"not-implemented"` sono **sempre presenti**, indipendentemente dal provider selezionato — nessuna via per cui il payload possa implicare una decodifica NR PHY che non esiste.
- Nessun dato qui descritto è RF live.

### Provider implementati (backend, `app/services/rf_source_provider.py`, nuovo file)

| Provider | Quando attivo | `source_mode` | `provenance` |
|---|---|---|---|
| `SimulatedRfProvider` | Default, sempre attivo se `RF_SDR_ENABLE=0` (default) | `simulated` | `SIMULATED` |
| `UnavailableRfProvider` | `RF_SOURCE_MODE=sdr_rx` esplicitamente richiesto ma nessun device rilevato | `unavailable` | `UNAVAILABLE` (numeri legacy comunque popolati come fallback, per non rompere la UI) |
| `SdrRxProvider` | Device rilevato **e** `RF_SDR_ENABLE=1` | **Skeleton — `read_snapshot()` ritorna comunque `unavailable`**, con limitation esplicita `"SDR RX capture not implemented in Patch 9C"` — nessuna acquisizione IQ reale in questa patch |

### Configurazione (variabili d'ambiente, tutte opzionali)

```text
RF_SOURCE_MODE = simulated | auto | sdr_rx     (default: simulated)
RF_SDR_ENABLE  = 0 | 1                         (default: 0)
RF_SDR_DEVICE  = auto | hackrf | bladerf       (default: auto)
```

Con i default (nessuna variabile impostata): **nessuna detection SDR viene mai tentata**, comportamento identico a prima di Patch 9C. Con `RF_SDR_ENABLE=1`, il backend esegue solo una singola enumerazione USB read-only (`lsusb`, timeout breve) per decidere il provider — mai apertura di stream, mai comandi di frequenza/gain, mai TX. In questo ambiente, verificato in Patch 9A/9C: nessun HackRF/bladeRF fisicamente presente, nessuna libreria SDR installata.

### Activation — restart controllato backend 8090 (2026-07-05)

Il codice di Patch 9C è stato attivato con un restart controllato **solo** del processo `uvicorn app.main:app --host 127.0.0.1 --port 8090` (PID prima: `291968`, PID dopo: `743558`). Nessun altro servizio toccato. Verificato via `curl`/probe WebSocket dopo il restart: `rf.source_mode="simulated"`, `rf.provenance="SIMULATED"`, campi legacy invariati, `legacy_synthetic` coerente, WebSocket `/ws/v16f/telemetry` funzionante con lo stesso schema. Le 4 route reali Vite/React (`#live-ops`/`#sentinel-x`/`#sentinel-x-legacy`/`#instrument-lab`) confermate PASS dopo il restart (0 console error, 0 network fail, 0 canvas zero-size, 0 overflow).

---

## Patch 9D — SDR RX Snapshot Implementation Design (2026-07-05, solo design)

**Nessuna implementazione in questa patch.** Design completo per una futura `Patch 9E` che sostituirà lo skeleton `SdrRxProvider` con acquisizione reale, RX-only, per HackRF One e bladeRF 2.0 micro xA4.

### Architettura progettata

`SdrRxProvider` → `SdrSnapshotCache` (worker in background, modello worker/cache) → `SoapySdrBackend` (strategia primaria) / `HackRfBackend` / `BladeRfBackend` (fallback). **REST/WS leggono sempre e solo la cache in memoria, mai l'hardware direttamente** — qualunque errore hardware resta isolato nel worker, senza mai propagarsi a `/api/v16f/telemetry/fast` o `/ws/v16f/telemetry`.

### Scelta tecnica

**SoapySDR raccomandato come strategia primaria** (API unica, un solo binding da mantenere per entrambi i device supportati); backend diretti (`libhackrf`/`libbladeRF`) solo come fallback se SoapySDR non risultasse disponibile/pacchettizzabile al momento dell'implementazione reale.

### Modello snapshot: worker/cache (non open/read/close per richiesta)

Un worker in background esegue un ciclo acquisizione→FFT→chiusura device ogni `RF_SDR_CACHE_TTL_MS`, scrivendo il risultato in una cache in memoria. Nessun handle device persistente tra un ciclo e l'altro. Timeout rigido (`RF_SDR_TIMEOUT_MS`) su ogni ciclo.

### Config futura progettata (solo lato server — nessun client remoto può impostarla)

```text
RF_SDR_CENTER_FREQ_HZ=3500000000
RF_SDR_SAMPLE_RATE_SPS=2000000
RF_SDR_GAIN_DB=24
RF_SDR_BANDWIDTH_HZ=2000000
RF_SDR_SNAPSHOT_SAMPLES=8192
RF_SDR_CACHE_TTL_MS=2000
RF_SDR_TIMEOUT_MS=800
```
Nessun endpoint REST/WS futuro deve mai esporre un modo per cambiare frequenza/gain/sample-rate da un client remoto.

### Payload futuro progettato (schema, non ancora implementato)

```json
{
  "rf": {
    "rsrp": -92.0, "rsrq": -9.6, "sinr": 22.0, "bler": 1.5,
    "throughputMbps": 1800, "activeUes": 1200,
    "source_mode": "sdr_rx",
    "source_device": "hackrf",
    "source_label": "HackRF One (RX)",
    "provenance": "SDR_RX_EVIDENCE",
    "nr_phy_decoded": false,
    "nr_phy_decoded_reason": "not-implemented",
    "legacy_synthetic": { "rsrp": -92.0, "rsrq": -9.6, "sinr": 22.0, "bler": 1.5, "throughputMbps": 1800, "activeUes": 1200 },
    "metrics": {
      "center_freq_hz": 3500000000, "sample_rate_sps": 2000000, "snapshot_samples": 8192,
      "peak_freq_hz": 3500012000, "peak_power_dbfs": -34.2, "noise_floor_dbfs": -78.5,
      "occupied_bw_hz": 180000, "spectrum_bins": 8192, "waterfall": ["..."],
      "timestamp": 1783200000.0, "device_serial": "...", "device_driver": "hackrf via SoapySDR",
      "rx_gain_db": 24, "calibration_status": "uncalibrated"
    },
    "limitations": ["dBFS is relative to ADC full-scale, NOT calibrated absolute dBm", "..."],
    "warnings": [], "snapshot_age_ms": 340, "cache_status": "fresh", "device_status": "connected"
  }
}
```
**Campi legacy top-level e `legacy_synthetic` restano sintetici anche in `source_mode="sdr_rx"`** (Opzione A, raccomandazione confermata) — non vengono mai derivati dallo spettro SDR, che non permette di calcolare BLER/SINR/RSRP NR senza un decoder dedicato.

### Metriche SDR realmente ottenibili (progettate, non ancora implementate)
Spettro FFT, waterfall ridotto, `peak_freq_hz`, `peak_power_dbfs` (dBFS relativo al fondo scala ADC, **non** dBm calibrato), `noise_floor_dbfs` (stima statistica), `occupied_bw_hz` (stima a soglia), metadata device.

### Metriche esplicitamente non dichiarabili senza decoder NR
BLER, RSRP/RSRQ/SINR NR reali, MCS, EVM, Cell ID, SSB decode, PCAP radio reale — nessuno di questi comparirà mai con `provenance:"SDR_RX_EVIDENCE"`.

### Error handling progettato
10 scenari (device assente/occupato/permessi insufficienti/driver mancante/timeout/buffer IQ vuoto/config non supportata/overflow USB/eccezione worker/disconnessione a runtime) — tutti isolati nel worker in background, mai propagati come errore a `/api/v16f/telemetry/fast` o `/ws/v16f/telemetry`, che devono restare sempre 200/attivi.

### RX-only guardrails progettati
Grep statico obbligatorio nella futura implementazione (`tx|transmit|start_tx|sync_tx|SOAPY_SDR_TX`); nessun endpoint di tuning/gain remoto; device aperto sempre e solo in modalità RX esplicita; nessun replay; nessuna emissione RF in nessuno scenario, incluso errore/fallback.

---

## Patch 10C — Instrument Integration Activation (2026-07-05)

Analogamente al provider RF dual-mode introdotto in Patch 9C, il payload di `/api/v16f/telemetry/fast` include ora un campo `instrument`, verificato read-only in questa sessione di chiusura documentale.

### Schema `instrument` osservato (read-only, `GET /api/v16f/telemetry/fast`, 2026-07-05)

```json
{
  "instrument": {
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
}
```

### Provenienza e stato

- `enabled=false`: lo strumento professionale è disabilitato per default in questo ambiente.
- `source_mode="instrument_disabled"` / `provenance="NOT_ENABLED"`: nessun dato di misura reale viene mai prodotto in questa configurazione.
- `readonly=true`, `safety_policy.allow_configuration_writes=false`, `safety_policy.allow_rf_output_control=false`: nessuna scrittura di configurazione né controllo di uscita RF è possibile in questa configurazione.
- `device_status="disabled"`, `metrics={}`: nessun dispositivo interrogato, nessuna metrica popolata.
- `limitations` auto-dichiarate nel payload: `"No VISA/SCPI discovery performed in Patch 10C"`, `"No instrument measurement performed in Patch 10C"` — confermano l'assenza di qualunque chiamata SCPI/VISA/vendor.

### Activation — restart controllato backend 8090 (dichiarato nel report Patch 10C Activation)

- PID prima del restart controllato: `743558`.
- PID dopo il restart controllato (dichiarato nel report): `781718`.
- PID osservato alla ripresa sessione, questa chiusura documentale (2026-07-05): `785527` — stesso comando esatto (`.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8090`), stesso binding `127.0.0.1:8090`, `/api/health` → `{"status":"ok",...}`. **Discrepanza PID non investigata** in questa sessione (fuori ambito: nessun restart/discovery autorizzati per la chiusura documentale) — vedi `KNOWN_LIMITATIONS.md` #14.

### Patch 10D

Resta **PLANNED** — implementazione reale dell'integrazione strumento professionale (acquisizione/misura reale via SCPI/VISA, se e quando autorizzata), analoga a quanto progettato per SDR in Patch 9D/9E. Nessun codice scritto in questa chiusura documentale.

---

## Patch 10D-B — Instrument Read-Only Provider Implementation (2026-07-05, codice non attivato a runtime)

Implementato in `backend/app/services/instrument_source_provider.py` un provider read-only dry-run (`ProfessionalInstrumentReadOnlyProvider`) e una factory `select_instrument_provider()` a 5 rami sicuri. **Il backend 8090 non è stato riavviato**: questo codice esiste su disco ma non è servito dal processo in esecuzione. Nessuna chiave esistente del payload (`enabled`,`source_mode`,`provenance`,`readonly`,`vendor`,`family`,`resource`,`transport`,`device_status`,`cache_status`,`snapshot_age_ms`,`metrics`,`safety_policy`,`limitations`,`warnings`) è stata rimossa o rinominata — solo aggiunte additive.

### Schema `instrument` esteso (verificato solo offline, non ancora nel payload live)

```json
{
  "schema_version": "instrument.v10d-b",
  "dry_run": true,
  "provider": "disabled | unavailable | read_only_dry_run",
  "capabilities": {"identity": false, "status": false, "spectrum": false, "power": false, "iq": false, "screenshot": false},
  "dependencies": {"pyvisa": "not_checked", "vendor_backend": "not_checked"},
  "resource_policy": {"allowlist_required": true, "resource_configured": false, "resource_allowed": false},
  "command_policy": {"allowlist_required": true, "executed_commands": 0, "blocked_commands": 0}
}
```

`dependencies` è sempre `"not_checked"` in questa patch: `_check_optional_visa_available()` è definita (lazy, function-local, nessun `ResourceManager()`/discovery) ma **non viene mai chiamata** da nessun percorso raggiungibile in Patch 10D-B — riservata a una futura patch di attivazione controllata.

### Factory `select_instrument_provider()` — logica a 5 rami

| Condizione | Provider | `source_mode` | `device_status` |
|---|---|---|---|
| `RF_INSTRUMENT_ENABLE` ≠ `1` (default) | `DisabledInstrumentProvider` | `instrument_disabled` | `disabled` |
| `ENABLE=1`, `DRY_RUN=0` (qualunque altra config) | `UnavailableInstrumentProvider` | `instrument_unavailable` | `activation_not_authorized` |
| `ENABLE=1`, `DRY_RUN=1`, resource/allowlist non validi | `UnavailableInstrumentProvider` | `instrument_unavailable` | `blocked_by_resource_policy` |
| `ENABLE=1`, `DRY_RUN=1`, resource/allowlist validi | `ProfessionalInstrumentReadOnlyProvider` | `instrument_read_only_dry_run` | `dry_run_not_connected` |
| Eccezione qualunque durante il parsing | `UnavailableInstrumentProvider` | `instrument_unavailable` | `internal_error_safe_fallback` |

Nessun ramo apre una sessione VISA, esegue discovery o invia SCPI.

### Variabili ambiente (Patch 10D-B, tutte opzionali, default sicuri)

```text
RF_INSTRUMENT_ENABLE            = 0 | 1        (default: 0)
RF_INSTRUMENT_MODE              = disabled     (default: disabled)
RF_INSTRUMENT_VENDOR            = none         (default: none)
RF_INSTRUMENT_FAMILY            = none         (default: none)
RF_INSTRUMENT_RESOURCE          = ""           (default: empty)
RF_INSTRUMENT_ALLOWLIST_RESOURCE = ""          (default: empty)
RF_INSTRUMENT_READONLY          = 1            (informational — readonly sempre forzato a true)
RF_INSTRUMENT_ALLOW_DISCOVERY   = 0            (informational — mai eseguito in questa patch)
RF_INSTRUMENT_ALLOW_MEASUREMENTS = 0           (informational — mai eseguito in questa patch)
RF_INSTRUMENT_COMMAND_PROFILE   = none         (informational)
RF_INSTRUMENT_CACHE_TTL_MS      = 1000         (parsato, non ancora consumato operativamente)
RF_INSTRUMENT_TIMEOUT_MS        = 500          (parsato, non ancora consumato operativamente)
RF_INSTRUMENT_DRY_RUN           = 1            (default: 1 — Patch 10D-B rifiuta sempre il non-dry-run)
```

### Safety policy estesa

`InstrumentSafetyPolicy`: `allow_discovery_queries` ora `False` di default (era `True` in Patch 10C); aggiunti `require_resource_allowlist=True`, `deny_unsafe_commands=True`, `dry_run=True`. Denylist ampliata (`*RST`,`*CLS`,`SYST:PRES`,`OUTP`,`SOUR`,`POW`,`FREQ`,`CONF`,`INIT`,`ABOR`,`TRIG`,`CAL`,`MMEM:DEL`,`FORM` e varianti già presenti da Patch 10C). Allowlist futura solo documentale ampliata con `READONLY:CAPABILITIES?`. Il campo top-level `safety_policy` nel payload resta a 3 chiavi (`readonly`,`allow_configuration_writes`,`allow_rf_output_control`) per piena compatibilità con Patch 10C.

### Stato di attivazione

Codice implementato e verificato **solo offline** (`py_compile`, import isolato, 4 scenari factory, grep di sicurezza — tutti PASS). **Il backend 8090 non è stato riavviato**: il payload REST/WS live resta invariato rispetto a Patch 10C (nessuna delle chiavi additive sopra è presente nella risposta osservata dopo l'implementazione). Attivazione a runtime rimandata a `Patch 10D-C — Activation Restart`, da autorizzare separatamente; anche dopo il restart il default resta `instrument_disabled` finché `RF_INSTRUMENT_ENABLE` non viene esplicitamente impostato.
