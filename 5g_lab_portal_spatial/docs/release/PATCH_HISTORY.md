# Patch History — 5G Lab Portal

## Patch 1 — Footer, background (portale statico)

- Rimozione dell'uso improprio di `SFONDO.png` come sfondo dati (due regole `body::before`/`body.portal-page::before` in `portal_theme.css`, sostituite con gradienti CSS).
- Fix dell'overlap del footer su tutte le pagine: `portal_footer.js` riscritto per appendere il footer come ultimo figlio di `document.body` (`position:static`), con `html,body{overflow-y:auto!important}` forzato via stile iniettato.
- Iterazioni intermedie (posizionamento come sibling, fixed→static) scartate dopo aver rotto layout specifici (grid a colonne, placeholder centrato in `core_console.html`).
- **Stato**: PASS (verificato su tutte le 11 pagine via misura DOM: `parentIsBody:true`, `fullWidth:true`).

## Patch 2 — Log freshness policy (backend statico, `main_engine.py`)

- Introdotti: `FRESHNESS_LIVE_THRESHOLD_S` (env-configurable, default 180s), `classify_source_type(path)`, `freshness_info(path, live_threshold_s=...)`.
- Riscritti `file_info(path)`, `protocol_events()`, `core_events()` per restituire `sources[]` (con `source_file`, `source_type`, `mtime`, `age_seconds`) e un campo `freshness` a livello top.
- Rimossa la funzione `tail_any()`, ormai morta.
- Backend riavviato una volta con autorizzazione esplicita passo-passo (PID 6979 → 97475); confermato nessun impatto su Open5GS/UERANSIM/interfacce.
- **Stato**: PASS (test sintattico + test reale degli endpoint).

## Patch 3 — Badge frontend LIVE/STALE/SIMULATED/EVIDENCE/UNKNOWN/DEGRADED/DOWN

- Creato `status_badges.js`: `escapeHtml(value)` (per prevenire XSS su testo derivato da log/API), `badgeHtml(state, note)`, `coreRanState(labStatus)`, `eventsFreshnessState(payload, fetchOk)`, esportato come `global.StatusBadges`.
- Integrato in `index.html` (badge `core-ran-badge`, `core-events-badge`), `protocol_console.html`, `core_console.html`, `alarms.html` (badge `freshness-badge`).
- Regola esplicita rispettata: log stale non forza mai un processo a DOWN.
- **Stato**: PASS.

## Patch 4 — Favicon/404, audit responsive

- Creato `favicon.svg` (36×36, sfondo rosso `#d11241`, testo bianco "5G", coerente col brand esistente).
- Aggiunto `<link rel="icon">` a tutte le 11 pagine HTML via `sed`, con backup `.prefavicon.bak` per ciascun file (verificati presenti in `/tmp/` al momento della stesura di questo documento).
- Audit responsive: 11 pagine × 3 risoluzioni (1366×768, 1920×1080, 2560×1440) → 0 overflow orizzontale, 0 errori.
- Investigata e **smentita** una presunta "terza colonna mancante" sulla Dashboard a 1366×768 — era un artefatto di compressione dello screenshot, non un difetto reale.
- **Stato**: PASS.

## Patch 5 — Consolidamento Protocol/Core/Alarms Console

- `protocol_console.html`: pannello "Protocol Session Summary", `TIMELINE_STEPS` (8 step con regex `okRe`/`rejectRe` su log reali), `updateSummary()`. Fix di un bug regex sull'estrazione timestamp (cattura di un carattere `:` finale spurio).
- `core_console.html`: pannello "Core NF Summary", tabella con `NF_LIST` (10 NF: AMF/SMF/UPF/AUSF/UDM/PCF/NSSF/BSF/UDR/NRF), `updateNfSummary()` — stato processo sempre da `/api/lab/status`, mai dedotto dai log.
- `alarms.html`: pannello "Alarm Correlation Summary", `updateAlarmSummary()` con conteggio per severità; testo dello stato "zero allarmi" reso esplicitamente non-assoluto.
- Verificato via screenshot: protocol console 14 eventi/3 sorgenti STALE/8-8 step in NO EVIDENCE (log-tail era traffico SBI, non NAS/NGAP); core console 10 NF UP, 4 con freshness reale, 6 onestamente UNKNOWN; alarms Total=1/Critical=0/Major=0/Info=1.
- **Stato**: PASS.

## Patch 5B — Audit visivo zoom/black-page (portale statico)

- Fase **diagnosi obbligatoria, nessun fix applicato**, su tutte le 11 pagine con focus su widget grafici (VSA, Multi-Site, Multi-RAT, Spatial Lab).
- Root cause confermata (via simulazione blocco CDN con `page.route().abort()`): `signal_analyzer.html` e `multirat_geo_twin.html` dipendono da Plotly via CDN esterno (`cdn.plot.ly`) senza fallback locale.
- Su VSA, un `ReferenceError` iniziale (`Plotly is not defined`) blocca in cascata TUTTI i widget della pagina, anche quelli non-Plotly (canvas puro).
- Su Multi-RAT, la rottura resta contenuta ai soli 3 widget Plotly-dipendenti; la mappa canvas principale resta funzionante.
- Confermato funzionante (nessun bug): fullscreen di Multi-Site (canvas 1568×828), fullscreen di Spatial Lab (canvas 1576×927), fullscreen di Multi-RAT in condizioni normali.
- **Non concluso**: causa esatta del rendering quasi-nero della Constellation VSA in fullscreen anche con Plotly caricato correttamente e zero errori — indagine interrotta prima di una conclusione, mai ripresa in questo ciclo.
- **Stato**: diagnosi completata e documentata; **nessuna patch correttiva autorizzata né applicata** in questo ciclo. La sessione si è spostata sull'audit del portale Vite/React (5177) su richiesta esplicita, senza mai ricevere risposta a "Autorizzi la patch correttiva?" per i problemi del portale statico.

## Patch 5C — Empty-state fallback (portale Vite/React)

Ambito: `/home/debian/5g_lab_portal_spatial/frontend/`. **Nota**: questa patch corregge problemi trovati con un audit *indipendente* sul portale Vite/React, non i problemi diagnosticati in Patch 5B (portale statico, mai corretti).

- **Auto-scroll non comandato** (`#sentinel-x-legacy`): causa reale in `TacticalCommandConsoleV19J.jsx:149-151` (`endRef.scrollIntoView()` risaliva fino al documento). Fix: scroll diretto sul contenitore interno (`scrollTop = scrollHeight`).
- **Sparkline vuoti**: causa più profonda del previsto — il WS invia payload incompatibile ma il componente normalizzava comunque qualunque messaggio con default costanti mascherati da dati live. Fix: guardia di forma + empty-state testuale `NO LIVE DATA`.
- **Waterfall scuro / Constellation senza badge**: alzato il pavimento colore del waterfall; aggiunto tracking `hasLiveData`/`wsStatus` e badge `SIMULATED`/`LIVE`.
- **Card "Sentinel Operating Environment" vuote**: causa reale, CSS Grid `align-items:stretch` di default forzava le card a 274px contro ~60px di contenuto. Fix: `align-items:start` + nota di stato onesta basata su `snapshot!==null` (non sul semplice `ws.onopen`).
- File toccati (7): `TacticalCommandConsoleV19J.jsx`, `RealtimeTelemetryBusV19F.jsx/.css`, `GpuRfRenderingEngineV19G.jsx/.css`, `EnterpriseSceneOrchestratorV19E.jsx/.css`.
- **Stato**: PASS (build + route test + verifica DOM/screenshot).

## Patch 5D — KPI Truthfulness / Baseline-State Labelling (portale Vite/React)

- Corregge il Known Issue HIGH lasciato aperto da Patch 5C: KPI numerici (Health Score, Severity, SINR, EVM, Noise floor, Risk index) mostrati come plausibili anche senza dati live.
- Aggiunto `hasLiveData` + funzione `kpiSourceLabel()` in `RealtimeTelemetryBusV19F.jsx`: badge `LIVE` / `BASELINE · WS ONLINE · NO COMPATIBLE TELEMETRY` / `BASELINE · WS DEGRADED` / `BASELINE · WS OFFLINE / RECONNECTING` / `BASELINE · WS CONNECTING`, tono neutro (`tone-baseline`) sui KPI quando non live.
- Raffinato in `GpuRfRenderingEngineV19G.jsx` il testo del badge già introdotto in Patch 5C (`rfStreamLabel()`), allineandolo allo stesso vocabolario esatto.
- File toccati (3, +1 CSS invariato): `RealtimeTelemetryBusV19F.jsx`, `RealtimeTelemetryBusV19F.css`, `GpuRfRenderingEngineV19G.jsx` (`GpuRfRenderingEngineV19G.css` non modificato).
- **Stato**: PASS (build + route test + verifica testuale badge su tutti e 6 i KPI).

---

**Nota di continuità**: le Patch 6/6A/6B/7A/7B non sono documentate in questo file (sessione di lavoro precedente all'aggiornamento documentale corrente; il ciclo di documentazione Patch 5E aveva chiuso a Patch 5D). Da Patch 7C in avanti la cronologia riprende con dettaglio completo. Riferimento rilevante: Patch 7B ha risolto, in una sessione precedente a questo aggiornamento documentale, il rendering "quasi-nero" della VSA Constellation in fullscreen su `signal_analyzer.html` (portale statico), citato come non concluso nella Limitation #8 di `KNOWN_LIMITATIONS.md` — voce ora corretta di conseguenza. La dipendenza da CDN esterno Plotly (stessa Limitation #8) resta invece non risolta.

## Patch 7C — Enterprise Global Refitting Sprint

- **Data**: 2026-07-04
- **Ambito**: portale statico (`/home/debian/lab/frontend/`) + un fix mirato sul portale Vite/React.
- **File modificati**:
  - `index.html` (Home/Dashboard) — controlli zoom/pan/fit/reset/fullscreen sul diagramma O-RAN, toggle interfacce 3GPP-O-RAN, toggle split O-RAN, evidence banner; toolbar Packet Sniffer (Pause/Clear/filtro protocollo/Export JSON, badge `SIMULATED FLOW`); toolbar SBA Console (Pause/Copy/Search); toolbar Spectrum (Fit/Freeze, badge `SIMULATED RF`); rinominato `#btn-master` in `■ LAB STOP (DEMO)` / `► RESUME LAB DEMO` con tooltip esplicito; etichetta stato core resa più onesta (`CORE LIVE · NO ACTIVE SESSION` invece di `CORE LIVE` generico quando non c'è sessione PDU attiva).
  - `multisite_network_twin.html` — zoom/pan/fit/reset sulla mappa, legenda (IP/Core, Microwave nominal/degraded).
  - `multirat_geo_twin.html` — zoom/pan/fit/reset sulla mappa, legenda (LTE/eNB, NR/gNB, Microwave/fibra, HO/mobility).
  - `spatial_simulator.html` — zoom/pan/fit/reset sulla scena, legenda tecnica preesistente (già ricca di riferimenti 3GPP/3GPP2: TS 38.300/38.211/38.213/38.214/38.331/TR 38.901/TS 23.287) spostata fuori dal wrapper trasformato per non essere scalata/traslata insieme allo zoom.
  - `alarms.html` — nuovo pannello "Come leggere lo stato allarmi" (severità, stati, relazione con NF/interfacce, checklist operatore, logica di escalation) — testo statico esplicativo, nessun dato di allarme reale alterato/inventato.
  - `/home/debian/5g_lab_portal_spatial/frontend/src/components/RfTheoryInstrumentsV18C.css` — fix overflow noto su `#sentinel-x-legacy` a risoluzioni ≤1440px: `.rf18c-grid`/`.rf18c-two`/`.rf18c-grid3` da `repeat(n,1fr)` a `repeat(n,minmax(0,1fr))`.
- **Problema**: diagramma O-RAN e mappe Multi-Site/Multi-RAT/Spatial Lab privi di zoom/pan/fullscreen; pannelli operativi (Packet Sniffer, SBA Console, Spectrum) senza controlli; etichetta "CORE LIVE" ambigua quando UPF non disponibile ma nessuna sessione attiva; pagina Alarms povera di contesto operativo; overflow orizzontale noto su `#sentinel-x-legacy` a risoluzioni ridotte.
- **Fix**: pattern uniforme CSS-transform (wrapper interno trasformato + contenitore esterno con `overflow:hidden`, legende/banner/modali sempre sibling esterni al wrapper per non essere scalati) replicato identicamente su 4 widget; nuovi controlli operativi (Pause/Clear/Filter/Export/Search/Copy/Fit/Freeze) senza alterare la semantica dei dati sottostanti; testo Alarms arricchito, dati reali invariati; fix CSS minimo (`minmax(0,1fr)`) sul Vite/React.
- **Test**: 10 pagine statiche + 1 file Vite/React verificati via Playwright (zoom/pan/fullscreen, screenshot, DOM); overflow `#sentinel-x-legacy` verificato assente a 1366×768 e 1440×900 dopo il fix (`scrollWidth === innerWidth`).
- **Esito**: **PASS**. Un WARN è emerso durante il test di responsive su `signal_analyzer.html` a 1366×768 (canvas `cvs-ray`/`packetCanvas` a 0-height, O-RAN E2E label overlap) — **non corretto in questa patch** (fuori ambito dichiarato: solo regressione su quel file), riportato onestamente e poi risolto nella Patch 7D successiva.
- **Rollback**: backup `.pre7c.bak` presenti per tutti i file toccati (verificati su disco: `index.html.pre7c.bak`, `multisite_network_twin.html.pre7c.bak`, `multirat_geo_twin.html.pre7c.bak`, `spatial_simulator.html.pre7c.bak`, `alarms.html.pre7c.bak`, `signal_analyzer.html.pre7c.bak` — quest'ultimo identico all'originale, il file non è stato modificato in 7C — `RfTheoryInstrumentsV18C.css.pre7c.bak`).

## Patch 7D — Signal Analyzer Responsive & O-RAN E2E Refinement

- **Data**: 2026-07-04
- **Ambito**: solo `/home/debian/lab/frontend/signal_analyzer.html` (portale statico).
- **File modificato**: `signal_analyzer.html`.
- **Problema**: a 1366×768, media query `@media(max-width:1400px)` impostava `.widgets-grid` a colonna singola senza un'altezza risolvibile (`height:auto`), facendo collassare a 0 l'altezza di `.widget-box` e di conseguenza dei canvas `cvs-ray` e `packetCanvas` (pattern: `canvas.height = canvas.parentElement.getBoundingClientRect().height`, che diventa 0 se il genitore è 0). In parallelo, le etichette dei pacchetti sul diagramma O-RAN E2E si sovrapponevano ad alta densità di traffico simulato.
- **Fix**:
  - `.widgets-grid{grid-auto-rows:280px; height:auto; min-height:0}` e `.widget-box{min-height:280px}` dentro la media query esistente — i canvas tornano ad avere un'altezza risolvibile.
  - Etichette pacchetti ridisegnate con sfondo a pillola scura semi-opaca dietro il testo, per leggibilità anche in sovrapposizione.
  - Aggiunto un gate `topoPackets.length < 2` allo spawn di nuovo traffico simulato, per ridurre la densità di pacchetti sovrapposti sullo stesso diagramma.
- **Test**: 1366×768, 1440×900, 1920×1080, 2560×1440 — **PASS** su tutte (canvas `cvs-ray`/`packetCanvas` non più a 0-height); VSA Constellation fullscreen (fix Patch 7B) verificata **non regredita**; O-RAN E2E fullscreen verificato leggibile; nessun backend/servizio toccato.
- **Esito**: **PASS**.
- **Rollback**: `signal_analyzer.html.pre7d.bak` (verificato presente su disco).

## Patch 8A — Vite/React Global Overflow Root Fix

- **Data**: 2026-07-04
- **Ambito**: solo `/home/debian/5g_lab_portal_spatial/frontend/src/components/LiveOpsCockpitV16.css`.
- **Problema**: `.v16-json-grid{grid-template-columns:1fr 1fr 1fr}` non vincolava la larghezza minima dei grid item; i tre pannelli `<pre>{JSON.stringify(...)}</pre>` (HTTP Bundle, WebSocket Snapshot, UERANSIM Snapshot), quando popolati con dati reali contenenti righe di log Open5GS fino a ~259 caratteri, forzavano un grid item a un min-content width di ~1530-1550px, portando `document.documentElement.scrollWidth` fino a **~3560px** contro un viewport di 1920px — overflow orizzontale sistemico sulla route reale di default `#live-ops`.
- **Fix**: `grid-template-columns:1fr 1fr 1fr` → `repeat(3, minmax(0, 1fr))`; aggiunto `.v16-json-panel{min-width:0}` (necessario per la variante a colonna singola della stessa griglia, già esistente sotto `@media(max-width:1500px)`, non modificata). **Nessun `overflow-x:hidden` globale introdotto** su `html`/`body`/`#root`.
- **Test**: 1920×1080, 1440×900, 1366×768, 1024×768 — tutte **PASS** (`scrollWidth === innerWidth`) con dati reali attivi (righe da 259/255 caratteri confermate scorrere internamente al pannello, non più espandere la pagina); route reali `#live-ops`/`#sentinel-x`/`#sentinel-x-legacy`/`#instrument-lab` tutte PASS (0 console error, 0 network fail, 0 canvas zero-size, 0 overflow); build PASS.
- **Esito**: **PASS**.
- **Rollback**: `LiveOpsCockpitV16.css.pre8a.bak` (verificato presente su disco).

## Patch 8B — LiveOps 3D Mirrored Text Fix

- **Data**: 2026-07-04
- **Ambito**: solo `/home/debian/5g_lab_portal_spatial/frontend/src/components/LiveOps3DSceneV16K.jsx`.
- **Problema**: `createWaterfallWall()` usava `MeshBasicMaterial({side: THREE.DoubleSide})` su un `PlaneGeometry` con `CanvasTexture` di testo ("RF WATERFALL / 5G NR SYNTH / PCAP TIMELINE") — comportamento noto di Three.js: la stessa texture, senza alcun ribaltamento, appare speculare se il piano è visto da dietro. La camera della scena orbita a 360° attorno al pannello (fisso nello spazio mondo), quindi il problema era periodicamente visibile.
- **Fix**: `side: THREE.DoubleSide` → `THREE.FrontSide`; introdotte due mesh (`front`/`back`) che condividono la stessa geometria e lo stesso materiale/texture, con `back.scale.x = -1` (tecnica standard Three.js per piani a doppia faccia leggibili da entrambi i lati). Nessuna nuova libreria, nessun nuovo canvas, camera/geometrie/altre label invariate.
- **Test**: campionamento su 14 istanti lungo l'orbita camera — testo confermato corretto (non speculare) nei momenti in cui il pannello risultava in inquadratura; 0 console error; build PASS; route reali PASS.
- **Nota onesta**: verifica diretta dell'angolazione "esattamente da dietro" limitata da una caratteristica di composizione/inquadratura della camera preesistente (il pannello esce spesso dal frame in quella fase dell'orbita, indipendentemente da questa patch) — la correttezza in quel caso si basa sulla solidità della tecnica standard applicata, non su una cattura diretta.
- **Esito**: **PASS** (con nota onesta sopra).
- **Rollback**: `LiveOps3DSceneV16K.jsx.pre8b.bak` (verificato presente su disco).

## Patch 8C — LiveOps 3D Label/HUD Collision Fix

- **Data**: 2026-07-04
- **Ambito**: solo `/home/debian/5g_lab_portal_spatial/frontend/src/components/LiveOps3DSceneV16K.jsx`.
- **Problema**: la label CSS2D `LEO / NTN RELAY` (proiettata da `CSS2DRenderer` in base a posizione 3D e orbita camera) poteva proiettarsi nell'area occupata dall'overlay HTML fisso `.liveops3d-overlay.status` (pannello WS/Version/Tick/FPS, `z-index:4` contro `z-index:3` del layer label, sfondo semi-opaco con blur) — la label veniva visivamente coperta. Chiarito che l'elemento in collisione è `.liveops3d-overlay.status` (interno allo stesso componente), non `.v16-ws-card` (componente separato, mai sovrapposto).
- **Fix**: logica di safe-area screen-space applicata solo alla label `sat`/LEO, eseguita ogni frame dopo `labelRenderer.render()`: lettura `getBoundingClientRect()` della label e del contenitore, e se la proiezione corrente ricade nella zona riservata (`HUD_SAFE_RIGHT=324px`, `HUD_SAFE_TOP=180px`, con `MARGIN=24px` e `TRIGGER_LEAD=48px` di anticipo), applicazione di un `translate()` correttivo calcolato dinamicamente (non un valore fisso) per liberarla. Nessuna label nascosta, nessuna camera/geometria toccata.
- **Test**: orbita camera completa (120s, un ciclo intero), 120 campioni a 1 misurazione/secondo — **overlap 0 su tutti i campioni**, label sempre visibile, 0 console error; iterazione di tuning intermedia documentata onestamente (con `TRIGGER_LEAD=20` erano residuati 1-2 campioni con overlap minimo di pochi pixel, chiuso aumentando l'anticipo a 48px); 1920/1440/1366/1024 PASS; non regressione Patch 8A e 8B confermata via diff diretto; route reali PASS; build PASS.
- **Esito**: **PASS**.
- **Rollback**: `LiveOps3DSceneV16K.jsx.pre8c.bak` (verificato presente su disco).

## Patch 8D — DATA_CONTRACT Discrepancy Investigation

- **Data**: 2026-07-05
- **Ambito**: **solo investigativo/read-only**. Nessun file modificato.
- **File letti**: `frontend/src/main.jsx`, `src/App.jsx`, `src/App.tsx`, `src/components/LiveOpsCockpitV16.jsx`, `src/hooks/useLiveTelemetryWsV16.js`, `src/hooks/useLiveOpsBundleV16.js`, `src/services/liveOpsServiceV16.js`, `src/services/apiConfig.js`; `backend/app/main.py`, `backend/app/routers/v16f_ultrafast_router.py`, `backend/app/services/telemetry_ultrafast_service.py`; `docs/release/DATA_CONTRACT_5G_PORTAL.md` (sola lettura).
- **Servizi interrogati in sola lettura**: `curl` su `/api/health`, `/api/v16f/health`, `/api/v16f/telemetry/fast` (porta 8090); probe WebSocket read-only (apertura, lettura 2 messaggi, chiusura) su `ws://127.0.0.1:8090/ws/v16f/telemetry`; verifica header CORS.
- **Problema investigato**: discrepanza tra `DATA_CONTRACT_5G_PORTAL.md` (che descriveva `#live-ops` come bloccato da CORS/404, con WebSocket su `ws://.../ws/telemetry` e schema incompatibile) e il comportamento realmente osservato durante Patch 8A/8B/8C (endpoint funzionante, WebSocket diverso, dati reali).
- **Root cause confermata**: il frontend reale (`main.jsx`→`App.jsx`, non `App.tsx` che è dead code) usa per `#live-ops` il componente `LiveOpsCockpitV16`, che consuma un router backend diverso (`/api/v16f/*`, aggiunto in un momento successivo alla stesura originale della documentazione) rispetto a quello documentato (`/ws/telemetry`, tuttora presente ma usato solo da `#sentinel-x`/`#sentinel-x-legacy`). Confermato anche un secondo `CORSMiddleware` permissivo nel backend che rende CORS non bloccante per questo canale.
- **Scoperte aggiuntive**: `core` (stati NF) = evidence-based da tail reale dei log Open5GS; `rf` (SINR/BLER/Throughput) = interamente sintetico (funzioni `sin`/`cos`); `pcap` = sintetico auto-dichiarato; `ueransim` = placeholder onesto non scansionato; nessun badge di provenienza (`LIVE`/`SIMULATED`/`BASELINE`) presente in `LiveOpsCockpitV16` — gap classificato UX GAP + DOCUMENTATION GAP, severità MEDIUM.
- **Esito**: **WARN** — investigazione completata, discrepanza confermata e circoscritta, nessuna correzione applicata in questa patch (per costruzione, era vietato).
- **Rollback**: non necessario, nessun file modificato.

## Patch 8E — DATA_CONTRACT Documentation Alignment

- **Data**: 2026-07-05
- **Ambito**: solo Markdown in `docs/release/` — nessun codice, CSS, JSX, backend, WebSocket, endpoint o servizio toccato.
- **File modificati**: `DATA_CONTRACT_5G_PORTAL.md` (riscrittura della sezione "Portale Vite/React — backend telemetria, porta 8090", nuova sezione "Frontend runtime reale", tabella provenienza dati, sezione "KPI provenance gap", tabella endpoint aggiornata, nota CORS aggiornata), `KNOWN_LIMITATIONS.md` (Limitation #1-4 aggiornata come investigata/riallineata, nuova voce #11 "LiveOps data provenance badge gap"), `PATCH_HISTORY.md` (questa voce + Patch 8D), `TEST_EVIDENCE_SUMMARY.md`, `FINAL_ACCEPTANCE_CHECKLIST.md`, `RUNBOOK_5G_LAB_PORTAL.md` (sezione breve aggiuntiva).
- **Problema risolto**: `DATA_CONTRACT_5G_PORTAL.md` non rifletteva più l'endpoint/WebSocket/schema realmente usato da `#live-ops` (root cause confermata in Patch 8D).
- **Fix**: riallineamento documentale completo per il canale v16f (endpoint, WebSocket, payload, provenienza dati, CORS), mantenendo esplicitamente aperto il gap di provenance UI (nuova voce Known Limitations #11), senza dichiarare RF live, senza dichiarare conformità 3GPP piena, senza dichiarare Sentinel Bridge implementato.
- **Test/verifiche**: grep di conferma su tutti i documenti (`Patch 8D`, `Patch 8E`, `/api/v16f/telemetry/fast`, `/ws/v16f/telemetry`, `LiveOpsCockpitV16`, `SIMULATED`, `EVIDENCE-BASED`, `UX GAP`, `Patch 8F`, `NOT CLAIMED`, `PLANNED`); verifica assenza di claim falsi (`full 3GPP compliant`, `RF live integration completed`, `Sentinel Bridge implemented`, `zero limitations`); verifica `find -newer` per confermare nessun file di codice toccato.
- **Esito**: **PASS**.
- **Rollback**: `<nomefile>.pre8e.bak` per ciascuno dei 6 file toccati (verificati presenti su disco).

## Patch 9A — RF Source Dual Mode Design (solo diagnosi/read-only)

- **Data**: 2026-07-05
- **Ambito**: solo lettura/diagnosi — nessun file modificato.
- **Oggetto**: design dell'evoluzione `#live-ops` verso un modello RF duale (`SIMULATED RF` / `SDR RX EVIDENCE`, dispositivi target HackRF One e bladeRF 2.0 micro xA4, RX-only).
- **Diagnosi**: confermata generazione RF attuale (`ultrafast_rf(tick)`, 100% sintetica); nessun dispositivo SDR fisicamente presente (`lsusb` pulito, nessun tool/libreria SDR installato); definiti con precisione i dati ottenibili da SDR RX generico (spettro/waterfall/IQ/picco/noise floor/banda occupata) vs i dati non ottenibili senza decoder NR dedicato (BLER/RSRP/RSRQ/SINR NR/MCS/EVM/Cell ID/SSB/PCAP radio).
- **Esito**: **PASS** (diagnosi/design), con WARN informativo: nessun hardware SDR presente in questo ambiente.
- **Rollback**: non necessario, nessun file modificato.

## Patch 9B — RF Source Provider Backend Design (solo design)

- **Data**: 2026-07-05
- **Ambito**: solo progettazione testuale — nessun file creato o modificato.
- **Oggetto**: design dettagliato dell'interfaccia `RfSourceProvider` (metodi `detect()`/`read_snapshot()`/`close()`), delle implementazioni `SimulatedRfProvider`/`SdrRxProvider`, del punto di integrazione in `ultrafast_global_snapshot()`, della gestione errori/fallback e del piano di test.
- **Esito**: **PASS** (design). Nessun'implementazione in questa fase.
- **Rollback**: non necessario, nessun file modificato.

## Patch 9C — RF Source Provider Backend Skeleton

- **Data**: 2026-07-05
- **Ambito**: backend 8090 — `backend/app/services/telemetry_ultrafast_service.py` (modificato) + `backend/app/services/rf_source_provider.py` (nuovo file).
- **File modificati/creati**:
  - **Creato**: `rf_source_provider.py` — `SimulatedRfProvider`, `UnavailableRfProvider`, `SdrRxProvider` (skeleton), `detect_sdr_devices()` (read-only, solo `lsusb`), `select_rf_provider()` (factory, selezione una tantum a livello di modulo).
  - **Modificato**: `telemetry_ultrafast_service.py` — 3 hunk: import di `select_rf_provider`; `_rf_provider = select_rf_provider(legacy_rf_fn=ultrafast_rf)` a livello modulo (dopo la definizione di `ultrafast_rf`, invariata); sostituzione di `"rf": ultrafast_rf(tick)` con `"rf": _rf_provider.read_snapshot(tick)` in `ultrafast_global_snapshot()`.
- **Problema/obiettivo**: introdurre il primo livello backend del modello RF dual-mode senza acquisizione IQ reale, mantenendo compatibilità totale con `LiveOpsCockpitV16`.
- **Fix**: vedi schema RF aggiornato in `DATA_CONTRACT_5G_PORTAL.md`. Default invariato (`RF_SOURCE_MODE=simulated`, `RF_SDR_ENABLE=0`) — comportamento identico a prima per qualunque consumer che non conosca i campi nuovi.
- **Test (fase implementazione, prima del restart)**: `py_compile` PASS su entrambi i file; grep RX-only su `rf_source_provider.py` — nessuna occorrenza reale di funzioni TX (solo 3 commenti che dichiarano il divieto); verifica funzionale offline (import isolato del modulo, non il servizio in esecuzione) su 4 scenari (default→simulated, sdr_rx richiesto senza hardware→unavailable con fallback legacy, auto senza hardware→simulated silenzioso, detection diretta→not found) tutti PASS; 4 route reali verificate invariate (backend non ancora riavviato in quella fase).
- **Esito implementazione**: **PASS**, con WARN dichiarato: verifica end-to-end REST/WS rimandata al restart (separatamente autorizzato).
- **Rollback**: `telemetry_ultrafast_service.py.pre9c.bak` (verificato presente); `rf_source_provider.py` da rimuovere (file nuovo, nessun backup necessario).

## Patch 9C — Activation (restart controllato backend 8090)

- **Data**: 2026-07-05
- **Ambito**: solo il processo `uvicorn app.main:app --host 127.0.0.1 --port 8090`.
- **Azione**: restart controllato per attivare il codice di Patch 9C. PID prima: `291968` → PID dopo: `743558`. Nessun altro servizio toccato (backend 8000, Vite 5177, statico 8080, Open5GS, UERANSIM tutti invariati, verificato via `curl`/`pgrep` prima e dopo).
- **Test post-restart**: health 8090 invariato (200 OK); REST `/api/v16f/telemetry/fast` → `rf.source_mode="simulated"`, `rf.provenance="SIMULATED"`, campi legacy (`rsrp/rsrq/sinr/bler/throughputMbps/activeUes`) presenti e coerenti con `legacy_synthetic` (verificato campo-per-campo, uguaglianza confermata); WebSocket `/ws/v16f/telemetry` — handshake OK, snapshot successivo con lo stesso schema, nessun comando mutante inviato; 4 route reali Vite/React tutte PASS (0 console error/network fail/canvas zero-size/overflow); non regressione `#live-ops` confermata (KPI popolati, scena 3D visibile, overlap label/HUD=0, nessuna dicitura "RF LIVE"/"LIVE RF").
- **Esito**: **PASS**.
- **Rollback**: vedi `ROLLBACK_PLAN.md` — richiede un nuovo restart del backend 8090 per diventare attivo.

## Patch 9D — SDR RX Snapshot Implementation Design

- **Data**: 2026-07-05
- **Ambito**: solo design/read-only — nessun file modificato, nessun servizio riavviato, nessun hardware interrogato (assunti i risultati già noti da Patch 9A/9C: nessun SDR presente, nessuna libreria/tool installata), nessuna acquisizione IQ, nessuna implementazione reale.
- **Oggetto**: progettazione completa della futura implementazione di `SdrRxProvider.read_snapshot()` per HackRF One e bladeRF 2.0 micro xA4, RX-only.
- **Architettura proposta**: `SdrRxProvider` (già introdotto come skeleton in Patch 9C) delegato a un `SdrSnapshotCache` — un worker in background (modello worker/cache) che periodicamente (ogni `RF_SDR_CACHE_TTL_MS`) esegue un ciclo acquisizione→FFT→chiusura device tramite un backend hardware intercambiabile (`SoapySdrBackend`/`HackRfBackend`/`BladeRfBackend`). **Principio cardine**: REST/WS leggono sempre e solo la cache, mai l'hardware direttamente — nessun errore SDR può mai abbattere `/api/v16f/telemetry/fast` o `/ws/v16f/telemetry`.
- **Scelta tecnica raccomandata**: SoapySDR come strategia primaria (API unica, un solo binding da mantenere per entrambi i device), backend diretti (`libhackrf`/`libbladeRF`) come fallback solo se SoapySDR risultasse non disponibile/non pacchettizzabile al momento dell'implementazione reale.
- **Modello snapshot raccomandato**: worker/cache (Modello 2), non open/read/close per singola richiesta — isola i guasti hardware nel worker, mantiene REST/WS non bloccanti a latenza costante.
- **Config futura proposta** (solo lato server, mai esposta a client remoti): `RF_SDR_CENTER_FREQ_HZ=3500000000`, `RF_SDR_SAMPLE_RATE_SPS=2000000`, `RF_SDR_GAIN_DB=24`, `RF_SDR_BANDWIDTH_HZ=2000000`, `RF_SDR_SNAPSHOT_SAMPLES=8192`, `RF_SDR_CACHE_TTL_MS=2000`, `RF_SDR_TIMEOUT_MS=800`.
- **Payload futuro progettato**: estende lo schema già introdotto in Patch 9C con `metrics` reali (`center_freq_hz`/`sample_rate_sps`/`peak_freq_hz`/`peak_power_dbfs`/`noise_floor_dbfs`/`occupied_bw_hz`/`spectrum_bins`/`waterfall`/`device_serial`/`device_driver`/`rx_gain_db`/`calibration_status`), più `warnings`/`snapshot_age_ms`/`cache_status`/`device_status`. Campi legacy top-level e `legacy_synthetic` restano sintetici anche in `source_mode="sdr_rx"` (Opzione A raccomandata) — mai derivati dallo spettro SDR.
- **Metriche ottenibili senza decoder NR**: spettro FFT, waterfall ridotto, peak frequency, peak power dBFS (relativo, non dBm calibrato), noise floor stimato, banda occupata stimata, metadata device.
- **Metriche esplicitamente non dichiarabili**: BLER, RSRP/RSRQ/SINR NR reali, MCS, EVM, Cell ID, SSB decode, PCAP radio reale — nessuno di questi deve mai comparire con provenienza `SDR_RX_EVIDENCE`.
- **Error handling progettato**: 10 scenari (device assente/occupato/permessi insufficienti/driver mancante/timeout/buffer vuoto/config non supportata/overflow USB/eccezione worker/disconnessione a runtime), tutti isolati nel worker, mai propagati come errore REST/WS.
- **RX-only guardrails progettati**: grep statico obbligatorio (`tx|transmit|start_tx|sync_tx|SOAPY_SDR_TX`), nessun endpoint di tuning/gain remoto, device sempre aperto in sola modalità RX.
- **Test plan futuro**: definito per 4 categorie (senza hardware, con HackRF, con bladeRF, regressione frontend).
- **UI futura consigliata** (non implementata): badge `SIMULATED RF`/`SDR RX EVIDENCE`/`RF DEVICE: HACKRF ONE`/`RF DEVICE: BLADERF 2.0 MICRO XA4`/`NR PHY: NOT DECODED`/`POWER: dBFS ESTIMATE`/`SPECTRUM: REAL RX`/`LEGACY KPI: SYNTHETIC`.
- **Esito**: **PASS** (design). Nessuna implementazione in questa fase.
- **Rollback**: non necessario, nessun file modificato.

## Patch 10C — Activation (restart controllato backend 8090) — chiusura documentale

- **Data**: 2026-07-05
- **Ambito**: solo il processo `uvicorn app.main:app --host 127.0.0.1 --port 8090`. Nessuna modifica di codice in questa sessione — solo append mirato ai 5 documenti di release (`PATCH_HISTORY.md`, `TEST_EVIDENCE_SUMMARY.md`, `KNOWN_LIMITATIONS.md`, `FINAL_ACCEPTANCE_CHECKLIST.md`, `DATA_CONTRACT_5G_PORTAL.md`).
- **Azione (dichiarata nel report di attivazione)**: restart controllato per attivare l'integrazione strumento professionale dual-mode (`instrument`, disabilitata di default). PID prima del restart: `743558` → PID dopo il restart dichiarato nel report: `781718`.
- **Ripresa sessione (2026-07-05, questa chiusura documentale)**: PID attualmente osservato in ascolto sulla 8090: `785527` (comando invariato: `.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8090`; uptime al momento della verifica ~685s/11m26s). **Discrepanza onesta**: il PID osservato (`785527`) non coincide con il PID dichiarato come esito del restart controllato nel report di attivazione (`781718`, verificato non più presente su `ps -p`). Nessuna causa investigata in questa sessione — vietato per vincolo esplicito (nessun restart, nessuna discovery). Il servizio risulta comunque sano, sullo stesso comando/porta/binding.
- **Verifica stato servizi (read-only, questa sessione)**: 5177 LISTEN (Vite), 8000 LISTEN, 8080 LISTEN (statico), 8090 LISTEN (PID 785527); `/api/health` (8090) → `{"status":"ok","service":"5g-spatial-secure-api","version":"0.1.0-rc1","security_mode":"baseline"}`; statico 8080 → 200; Vite 5177 → 200.
- **Verifica payload `instrument` (read-only, `GET /api/v16f/telemetry/fast`)**: campo `instrument` presente e conforme — `enabled:false`, `source_mode:"instrument_disabled"`, `provenance:"NOT_ENABLED"`, `readonly:true`, `device_status:"disabled"`, `metrics:{}`, `safety_policy.allow_configuration_writes:false`, `safety_policy.allow_rf_output_control:false`. Nessuna discovery hardware, nessuna chiamata SCPI/VISA/vendor eseguita — confermato anche dai `limitations` auto-dichiarati nel payload stesso (`"No VISA/SCPI discovery performed in Patch 10C"`, `"No instrument measurement performed in Patch 10C"`).
- **Open5GS/UERANSIM/routing/iptables/interfacce**: non toccati, non interrogati in questa sessione — fuori ambito per vincolo esplicito.
- **Esito**: **PASS** per lo stato funzionale osservato (servizi attivi, health OK, `instrument` correttamente disabilitato/read-only per default), con **WARN** esplicito sulla discrepanza PID dichiarato (`781718`) vs PID osservato (`785527`), non investigata per vincolo di ambito.
- **Patch 10D**: resta **PLANNED** — nessuna implementazione reale dello strumento professionale in questa patch né in questa chiusura documentale.
- **Rollback**: vedi `ROLLBACK_PLAN.md` — coerente con il pattern già usato per Patch 9C Activation (richiede un nuovo restart controllato del backend 8090).

## Patch 10D-B — Instrument Read-Only Provider Implementation

- **Data**: 2026-07-05
- **Ambito**: solo codice backend, additive-only. Nessuna attivazione reale, nessun restart, nessuna discovery VISA, nessuna query/write SCPI, nessuna installazione pacchetti.
- **File modificati**: `backend/app/services/instrument_source_provider.py` (unico file toccato).
- **File non modificati (verificato)**: `backend/app/services/telemetry_ultrafast_service.py` — l'integrazione additive-only di Patch 10C (`"instrument": _instrument_provider.read_snapshot(tick)`) era già sufficiente; nessuna chiave esistente (`rf`/`core`/`ueransim`/`pcap`/`security_boundary`) toccata.
- **Backup creato**: `instrument_source_provider.py.pre10d-b.bak` (md5 confermato identico all'originale al momento della creazione).
- **Nuove classi/funzioni**: `ProfessionalInstrumentReadOnlyProvider` (provider read-only dry-run, mai apre sessioni/invia comandi), `_check_optional_visa_available()` (funzione lazy definita ma **mai chiamata** in questa patch — riservata a una futura patch di attivazione controllata), `_build_extension()`/`_capabilities_none()`/`_dependencies_not_checked()` (estensione additive-only del payload), helper env-parsing sicuri (`_env_flag`/`_env_str`/`_env_int`/`_parse_allowlist`). `DisabledInstrumentProvider` e `UnavailableInstrumentProvider` mantenuti, estesi solo con l'estensione additive-only del payload. `InstrumentSkeletonProvider` (Patch 10C) lasciato invariato e non utilizzato.
- **Factory `select_instrument_provider()` aggiornata**: 5 rami sicuri — `RF_INSTRUMENT_ENABLE≠1` → `Disabled`; `ENABLE=1`+`DRY_RUN=0` (qualunque altra config) → `Unavailable("activation_not_authorized")`; `ENABLE=1`+`DRY_RUN=1` senza resource/allowlist validi → `Unavailable("blocked_by_resource_policy")`; `ENABLE=1`+`DRY_RUN=1` con resource/allowlist validi → `ProfessionalInstrumentReadOnlyProvider` (solo dry-run); qualunque eccezione → `Unavailable("internal_error_safe_fallback")`. Nessun percorso apre una sessione VISA o invia SCPI.
- **Safety policy estesa**: `allow_discovery_queries` default cambiato da `True` a `False`; aggiunti `require_resource_allowlist`, `deny_unsafe_commands`, `dry_run` (default `True`); denylist e allowlist ampliate come da specifica Patch 10D-B (denylist ora include anche `*CLS`,`OUTP`,`SOUR`,`POW`,`FREQ`,`CONF`,`INIT`,`TRIG`,`CAL`,`MMEM:DEL`,`FORM`; allowlist futura documentale ora include anche `READONLY:CAPABILITIES?`).
- **Test eseguiti (tutti offline, senza hardware)**: `py_compile` PASS su entrambi i file; import isolato — 46 nuovi moduli caricati, **zero** moduli `pyvisa`/`RsInstrument`/`usb`/`vxi11`/`zeroconf`; 4 scenari factory (default disabled, dry-run con allowlist valida, dry-run senza allowlist, non-dry-run) tutti **PASS** con asserzioni campo-per-campo; grep di sicurezza (`ResourceManager(`, `list_resources(`, `open_resource(`, `.query(`, `.write(`, `socket.connect`, `subprocess`) — le uniche 4 occorrenze trovate sono in commenti/docstring che *dichiarano* l'assenza di queste chiamate, **zero** occorrenze in codice operativo eseguibile.
- **Verifica runtime (backend NON riavviato)**: payload live su REST (`/api/v16f/telemetry/fast`) confermato ancora sullo schema Patch 10C (nessuna chiave `schema_version`/`dry_run`/`provider` presente) — **prova diretta che il nuovo codice non è attivo a runtime**, PID 8090 invariato (`785527`), Open5GS/UERANSIM invariati (10 processi Open5GS, `ogstun`/`uesimtun0` con indirizzi invariati).
- **Esito**: **PASS**. Codice implementato e verificato interamente offline; **non attivato a runtime** — il backend 8090 in esecuzione continua a usare il codice precedente finché non sarà autorizzato un restart separato (Patch 10D-C).
- **Patch 10D-C — Activation Restart**: resta da autorizzare separatamente. Nessuna implementazione ulteriore in questa patch.
- **Rollback**: ripristino diretto da `instrument_source_provider.py.pre10d-b.bak`; nessun restart necessario per il rollback stesso (il codice attivo a runtime non è comunque cambiato).

## Patch 10D-C — Activation Restart + Portal View Smoke Test

- **Data**: 2026-07-05
- **Ambito**: solo restart controllato del processo `uvicorn app.main:app --host 127.0.0.1 --port 8090`, seguito da smoke test read-only del portale. Nessuna modifica codice, nessuna installazione, nessuna discovery/SCPI/VISA.
- **Azione**: stop controllato (`SIGTERM`) del processo PID `785527`, verificato terminato e porta liberata; restart con lo stesso comando esatto e stessa working directory (`/home/debian/5g_lab_portal_spatial/backend`) → nuovo PID `799185`, nessun processo duplicato verificato.
- **Verifica runtime post-restart**: `/api/health` → 200 OK; payload REST (`/api/v16f/telemetry/fast`) e WS (`/ws/v16f/telemetry`, probe read-only) entrambi confermano il codice di Patch 10D-B ora attivo (campi additive-only `schema_version=instrument.v10d-b`, `dry_run=true`, `provider=disabled`, `capabilities`/`dependencies`/`resource_policy`/`command_policy` presenti, prima assenti a runtime) mantenendo `enabled=false`, `source_mode=instrument_disabled`, `provenance=NOT_ENABLED`, `device_status=disabled`, `metrics={}`.
- **Smoke test portale**: statico 8080 (200), 4 route Vite/React (`#live-ops`,`#instrument-lab`,`#sentinel-x`,`#sentinel-x-legacy`) tutte 200 a livello HTTP; entry point reale `/src/main.jsx` verificato 200. **WARN dichiarato**: verifica visiva browser (console error/network fail/canvas zero-size/overflow) non eseguita per assenza di binari Playwright/Chromium installati in questo ambiente — non installati per rispettare il vincolo "nessuna installazione" di questa patch.
- **Esito**: **PASS** per l'attivazione runtime e la raggiungibilità HTTP, con **WARN** dichiarato sul limite dello smoke test visivo.
- **Open5GS/UERANSIM/8000/statico 8080/Vite 5177**: non toccati, non riavviati.
- **Rollback**: stop del PID corrente + restart puntando al codice precedente il commit di Patch 10D-B (o ripristino da `instrument_source_provider.py.pre10d-b.bak` seguito da restart).

## Checkpoint — Post Patch 10D-C (2026-07-05)

- **Ambito**: solo verifica read-only + documentazione. Nessuna modifica codice, nessun restart, nessuna installazione, nessuna discovery/SCPI/VISA in questa fase.
- **Verifica manuale utente**: confermata positiva — tutti i portali risultano avviati/raggiungibili ("tutti i portali sono riusciti/partono").
- **Stato onesto**: alcune funzioni sono verificate complete e funzionanti (attivazione Patch 10D-B a runtime, provider strumenti correttamente `instrument_disabled`/safe, tutti e 4 i servizi raggiungibili); altre restano non completate o da rifinire (smoke test visivo browser mai eseguito in questo ciclo per assenza di Playwright/Chromium; eventuali rifiniture UI/UX zoom/pan/contenuti non ri-verificate in questo checkpoint — nessuna di queste viene dichiarata completata qui).
- **Patch 10D-D**: resta **PLANNED**, non autorizzata.
- **Strumenti reali/VISA/SCPI**: restano **PLANNED**, non autorizzati.
