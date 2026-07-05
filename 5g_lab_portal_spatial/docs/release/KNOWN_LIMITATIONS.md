# Known Limitations — 5G Lab Portal

Ogni voce riporta severità, impatto, workaround e azione futura proposta. Nessuna voce qui è stata risolta nel ciclo Patch 1-5D salvo dove esplicitamente indicato. Aggiornato dopo Patch 7C/7D/8A/8B/8C (2026-07-04): vedi voci marcate **RISOLTO** e la nuova sezione in fondo.

---

### 1. `#live-ops` — CORS/404 preesistenti su `/api/v16f/telemetry/fast`
- **Severità**: MEDIUM
- **Impatto**: la route `#live-ops` non riceve mai dati REST da questo endpoint; console piena di errori CORS/`net::ERR_FAILED`/404 ripetuti (uno ogni pochi secondi).
- **Workaround**: nessuno lato frontend senza toccare CORS (esplicitamente fuori ambito). L'utente può ignorare questi errori specifici in console, sapendo che sono preesistenti e non introdotti da Patch 5C/5D.
- **Azione futura proposta**: aggiungere header CORS lato backend porta 8090, oppure servire il frontend dallo stesso origin del backend.

### 2. Backend 8090 — WebSocket online ma payload incompatibile
- **Severità**: HIGH
- **Impatto**: `ws://127.0.0.1:8090/ws/telemetry` si connette correttamente ma invia `{profile, kpi, state, beam}` invece di `{rf, core}` — nessun componente frontend riceve mai dati realmente live in questo ambiente.
- **Workaround**: Patch 5C/5D hanno reso questo stato onesto (badge `BASELINE`/`SIMULATED` invece di dati finti), ma non risolvono il disallineamento.
- **Azione futura proposta**: allineare lo schema backend a `{rf, core, tick, version}`, oppure aggiornare i normalizzatori frontend per accettare `{profile, kpi, state, beam}` — decisione da prendere con chi possiede il backend 8090.

### 3. `BASELINE · WS ONLINE · NO COMPATIBLE TELEMETRY` — interpretazione
- **Severità**: INFO (non è un bug, è una spiegazione)
- **Impatto**: un osservatore superficiale potrebbe scambiare questo badge per un errore di connessione.
- **Workaround**: badge testuale esplicito già implementato (Patch 5D); vedi `RUNBOOK_5G_LAB_PORTAL.md` §14 per l'interpretazione corretta.
- **Azione futura proposta**: nessuna, se non estendere lo stesso badge ad altri eventuali componenti futuri che consumano lo stesso WS.

### 4. Valori RF/KPI possono essere baseline/simulati, non live
- **Severità**: MEDIUM
- **Impatto**: SINR, RSRP, BLER, Health Score, EVM mostrati in `RealtimeTelemetryBusV19F` e `GpuRfRenderingEngineV19G` sono spesso valori di default o generati proceduralmente, non misure reali, a causa della Limitation #2.
- **Workaround**: badge `BASELINE`/`SIMULATED` introdotti in Patch 5D rendono questo esplicito; i valori numerici restano visibili (non nascosti) ma etichettati.
- **Azione futura proposta**: risolvere la Limitation #2 renderebbe questi valori realmente LIVE.

### 5. Due portali distinti, non intercambiabili
- **Severità**: LOW (rischio di confusione operativa, non un bug)
- **Impatto**: chi opera sul lab potrebbe confondere `/home/debian/lab/frontend` (statico, 8080) con `/home/debian/5g_lab_portal_spatial/frontend` (Vite/React, 5177) — hanno storie di patch diverse e stato diverso.
- **Workaround**: questo set di documenti (in particolare `RELEASE_NOTES_5G_ENTERPRISE.md`) chiarisce esplicitamente la distinzione.
- **Azione futura proposta**: nessuna fusione dei due portali è pianificata né raccomandata in questo ciclo.

### 6. Log STALE non implica sistema DOWN
- **Severità**: INFO (regola di interpretazione, non un difetto)
- **Impatto**: un log non aggiornato da tempo potrebbe far pensare a un guasto, quando in realtà il processo è vivo e semplicemente non ha generato nuove righe.
- **Workaround**: badge di freshness separato dallo stato di processo, introdotto in Patch 2/3; regola esplicita: mai dedurre DOWN da un log stale.
- **Azione futura proposta**: nessuna, comportamento già corretto.

### 7. `ATTENTION` può derivare da rumore storico nei log
- **Severità**: LOW
- **Impatto**: un conteggio di eventi "attention" nei log storici può alzare un indicatore anche se non c'è nulla di attivo in corso.
- **Workaround**: la timeline del Protocol Console mostra esplicitamente `NO EVIDENCE` quando non ci sono match regex reali per lo step corrente, invece di dedurre uno stato.
- **Azione futura proposta**: eventualmente introdurre una finestra temporale esplicita ("eventi nelle ultime N ore") per distinguere rumore storico da attività corrente.

### 8. Portale statico — zoom/black-page diagnosticati (Patch 5B) — **PARZIALMENTE RISOLTO**
- **Severità**: HIGH → MEDIUM (dopo risoluzione parziale)
- **Impatto**: `signal_analyzer.html` (VSA) e `multirat_geo_twin.html` dipendono da un CDN esterno Plotly senza fallback locale; se il CDN è irraggiungibile, su VSA l'intera pagina si rompe (cascata di errore JS che blocca anche widget non-Plotly). **Questa parte resta valida e non risolta.**
- **RISOLTO in Patch 7B** (sessione precedente a questo aggiornamento documentale): il rendering quasi-nero della Constellation VSA in fullscreen era causato da un artefatto di compositing CSS (`#fs-overlay` con `backdrop-filter:blur()` + `background` semi-trasparente sopra un widget che doveva restare opaco, in ambiente Chromium headless senza GPU) — risolto rimuovendo `backdrop-filter` e impostando `background:transparent`. Verificato senza regressioni nelle successive Patch 7C/7D.
- **Workaround residuo**: nessuno applicato per la dipendenza CDN — non ha mai ricevuto un'autorizzazione di fix in questo ciclo.
- **Azione futura proposta**: aprire una patch dedicata per bundlare Plotly localmente o aggiungere un fallback/guardia contro cascata di errore in caso di CDN irraggiungibile.

### 9. Warning residui non bloccanti
- **Severità**: LOW
- **Impatto**: warning del build Vite (`PLUGIN_TIMINGS`) non bloccanti, non correlati a un difetto funzionale.
- **Workaround**: nessuno necessario.
- **Azione futura proposta**: nessuna azione richiesta a meno che i tempi di build peggiorino sensibilmente.

### 10. Sentinel Bridge non implementato
- **Severità**: MEDIUM (aspettativa da gestire, non un difetto)
- **Impatto**: nessuna integrazione SIEM/SOAR reale esiste oggi; chi si aspettasse un export funzionante ne resterebbe deluso.
- **Workaround**: nessuno — vedi `SENTINEL_BRIDGE_READINESS.md` per lo stato esatto (PLANNED).
- **Azione futura proposta**: seguire i 5 requisiti elencati in `SENTINEL_BRIDGE_READINESS.md` prima di dichiararlo pronto.
- **Stato dopo Patch 7C-8C**: invariato. Nessuna delle patch di questo aggiornamento tocca il Sentinel Bridge; resta **PLANNED**.

---

## Voci risolte in Patch 7C / 7D / 8A / 8B / 8C (2026-07-04)

Queste voci **non esistevano ancora** come limitazione documentata al momento di Patch 5D (sono state trovate e risolte in patch successive, all'interno dello stesso filone di lavoro che ha prodotto questo aggiornamento) — riportate qui solo a scopo di tracciabilità, non perché rimuovano un impatto che l'utente avesse già letto come "noto":

1. **`signal_analyzer.html` — canvas `cvs-ray` a 0-height a 1366×768** — **RISOLTO** (Patch 7D): causa, media query senza altezza risolvibile; fix, `grid-auto-rows`/`min-height` espliciti.
2. **`signal_analyzer.html` — canvas `packetCanvas` a 0-height a 1366×768** — **RISOLTO** (Patch 7D), stessa causa/fix del punto 1.
3. **`signal_analyzer.html` — sovrapposizione etichette pacchetti sul diagramma O-RAN E2E** — **RISOLTO** (Patch 7D): etichette ridisegnate con sfondo a pillola e densità di traffico simulato ridotta.
4. **Overflow orizzontale sistemico su Vite/React `#live-ops` (`.v16-json-grid`)** — **RISOLTO** (Patch 8A): `grid-template-columns` senza `minmax(0,…)`; fix minimo, nessun `overflow-x:hidden` globale.
5. **Testo 3D speculare/capovolto sul pannello waterfall di LiveOps (`RF WATERFALL / 5G NR SYNTH / PCAP TIMELINE`)** — **RISOLTO** (Patch 8B): `THREE.DoubleSide` → `FrontSide` + mesh fronte/retro.
6. **Collisione label CSS2D `LEO / NTN RELAY` con l'overlay HUD `.liveops3d-overlay.status`** — **RISOLTO** (Patch 8C): safe-area screen-space dinamica.
7. **Overflow `#sentinel-x-legacy` da `.rf18c-grid`/`.rf18c-two`/`.rf18c-grid3` a risoluzioni ≤1440px** — **RISOLTO** (Patch 7C): `minmax(0,1fr)` sulle stesse classi.

### Limitazioni confermate ancora valide (non toccate da Patch 7C-8C)

- **Sentinel Bridge resta PLANNED**, non implementato (vedi voce #10 sopra e `SENTINEL_BRIDGE_READINESS.md`).
- **RF Vite/React resta simulato** dove già dichiarato tale (badge `SIMULATED`/`BASELINE` di Patch 5C/5D invariati; Patch 7C ha aggiunto badge `SIMULATED RF`/`SIMULATED FLOW` equivalenti sul portale statico, stesso principio, nessun dato reale spacciato per live).
- **Nessuna conformità 3GPP piena dichiarata** — vedi `3GPP_COHERENCE_MATRIX.md`.
- **Distinzione LIVE/SIMULATED/STALE/BASELINE** resta invariata e rispettata in tutte le nuove patch.
- **Limitation #1, #2, #3, #4 (WebSocket 8090 schema/CORS) — investigata e riallineata in Patch 8D/8E (2026-07-05)**: la discrepanza segnalata qui in precedenza è stata investigata a fondo (Patch 8D, lettura diretta del codice sorgente backend + probe read-only) e la documentazione `DATA_CONTRACT_5G_PORTAL.md` è stata riallineata (Patch 8E) per riflettere lo stato reale: `#live-ops`/`LiveOpsCockpitV16` usa un endpoint/WebSocket (`/api/v16f/telemetry/fast`, `/ws/v16f/telemetry`) diverso da quello originariamente documentato per questa limitazione (`/ws/telemetry`, ancora presente ma consumato solo da `#sentinel-x`/`#sentinel-x-legacy`). CORS non risulta più bloccare questo canale (secondo `CORSMiddleware` permissivo nel backend, non introdotto da alcuna patch di questo ciclo frontend). **`DATA_CONTRACT_5G_PORTAL.md` è ora riallineato** per il canale v16f; resta aperto solo il gap di provenance UI descritto nella nuova voce sotto.

### 11. LiveOps data provenance badge gap — OPEN / TECH-DEBT
- **Severità**: MEDIUM
- **Impatto**: `LiveOpsCockpitV16` (route reale `#live-ops`) mostra nello stesso riquadro "5GC Live" sia stati NF evidence-based (derivati da tail reale dei log Open5GS) sia KPI RF (SINR/BLER/Throughput) interamente simulati (funzioni sintetiche `sin`/`cos`), **senza alcun badge esplicito** che distingua le due provenienze. Il meccanismo di gating LIVE/simulato esiste altrove nel codebase (`PORTAL_MODE`/`isLiveMode()` in `services/apiConfig.js`) ma non è collegato a questo componente.
- **Workaround**: consultare `DATA_CONTRACT_5G_PORTAL.md` (sezione "Provenienza dati" e "KPI provenance gap"), aggiornato in Patch 8E, per sapere quali campi sono EVIDENCE-BASED e quali SIMULATED.
- **Azione futura proposta**: `Patch 8F — LiveOps Provenance Badge UI` (non applicata, da autorizzare separatamente se ancora ritenuta necessaria) — introdurrebbe badge per `#live-ops` analoghi a quelli già esistenti su `RealtimeTelemetryBusV19F`/`GpuRfRenderingEngineV19G` (Patch 5D).
- **Classificazione**: UX GAP + DOCUMENTATION GAP, non un bug funzionale.
- **Eventuale doppia connessione WebSocket su `#live-ops` (nota da Patch 6B)**: non verificata in questo aggiornamento — nessuna evidenza diretta raccolta in un senso o nell'altro durante i test di Patch 8A/8B/8C, quindi non viene dichiarata né risolta né aperta.
- **`SFONDO.png` come sfondo enterprise**: nessuna patch di questo aggiornamento (7C/7D/8A/8B/8C) lo ha reintrodotto; resta rimosso come da Patch 1, nessun claim di integrazione da fare qui.

### 12. SDR RX reale — SKELETON / NOT IMPLEMENTED (Patch 9A/9B/9C, design completato in Patch 9D, 2026-07-05)
- **Severità**: INFO (roadmap dichiarata, non un difetto)
- **Impatto**: il campo `rf` di `/api/v16f/telemetry/fast`/`ws://.../ws/v16f/telemetry` ha ora uno schema dual-mode (`source_mode`/`provenance`/`legacy_synthetic`/`metrics`/`limitations`), ma **resta sempre `SIMULATED`** in questo ambiente — nessun hardware SDR (HackRF One/bladeRF 2.0 micro xA4) è fisicamente presente (confermato via `lsusb`, Patch 9A), e la classe `SdrRxProvider` introdotta in Patch 9C è uno **skeleton strutturale**: `read_snapshot()` ritorna sempre `source_mode:"unavailable"` con la limitation esplicita `"SDR RX capture not implemented in Patch 9C"` — nessuna acquisizione IQ, nessuno stream, nessun TX.
- **Workaround**: nessuno necessario — il comportamento di default (`RF_SOURCE_MODE=simulated`, `RF_SDR_ENABLE=0`) è identico a prima di Patch 9C, nessuna regressione.
- **Design completato (Patch 9D, 2026-07-05)**: architettura worker/cache, scelta tecnica (SoapySDR primaria, backend diretti come fallback), config futura, payload futuro, error handling e RX-only guardrails progettati per intero — vedi `DATA_CONTRACT_5G_PORTAL.md` sezione "Patch 9D". **Nessuna implementazione**: resta uno skeleton, nessun codice scritto in Patch 9D.
- **Azione futura proposta**: `Patch 9E — SDR RX Snapshot Implementation (codice)` — acquisizione IQ reale RX-only via HackRF/bladeRF secondo il design di Patch 9D, da autorizzare solo quando hardware SDR fisico sarà effettivamente disponibile per un test end-to-end reale. Eventuale `Patch 9F` per estendere UI/documentazione una volta implementata — da valutare insieme alla già proposta `Patch 8F — LiveOps Provenance Badge UI` (gap voce #11 sopra, ancora aperto, non affrontato da Patch 9A/9B/9C/9D).
- **Classificazione**: SKELETON / NOT IMPLEMENTED (design completo, codice non scritto), RX-only per design (nessuna funzione TX presente nel codice attuale, verificato via grep; guardrail RX-only progettati anche per la futura implementazione).

### 13. Instrument professionale — DISABLED BY DESIGN (Patch 10C, 2026-07-05)
- **Severità**: INFO (comportamento di default atteso, non un difetto)
- **Impatto**: il campo `instrument` di `/api/v16f/telemetry/fast` è presente nello schema ma resta sempre disabilitato in questo ambiente: `enabled=false`, `source_mode="instrument_disabled"`, `provenance="NOT_ENABLED"`, `readonly=true`, `device_status="disabled"`, `metrics={}`. Nessuna discovery hardware, nessuna chiamata SCPI/VISA/vendor viene mai eseguita con questa configurazione (confermato dai `limitations` auto-dichiarati nel payload).
- **Workaround**: nessuno necessario — comportamento di default sicuro, `safety_policy.allow_configuration_writes=false` e `safety_policy.allow_rf_output_control=false` sempre applicati.
- **Azione futura proposta**: `Patch 10D` — implementazione reale dell'integrazione strumento professionale, resta **PLANNED**, da autorizzare separatamente.
- **Classificazione**: SKELETON / DISABLED BY DEFAULT, coerente con il pattern già adottato per il provider RF SDR (Limitation #12).

### 14. PID backend 8090 — discrepanza tra report di attivazione Patch 10C e osservazione a ripresa sessione (nota operativa, non funzionale)
- **Severità**: INFO / tracciamento operativo (nessun impatto funzionale osservato)
- **Impatto**: il report di attivazione di Patch 10C dichiara PID post-restart `781718`; alla ripresa sessione (2026-07-05, chiusura documentale) il PID realmente in ascolto sulla porta 8090 è `785527` — stesso comando esatto, stesso binding, servizio sano (`/api/health` → `ok`). Nessuna causa determinata in questa sessione (fuori ambito: nessun restart, nessuna discovery autorizzati per questa chiusura documentale).
- **Workaround**: nessuno necessario per il funzionamento attuale — il servizio risponde correttamente indipendentemente dal PID esatto.
- **Azione futura proposta**: se richiesto in una sessione futura con restart esplicitamente autorizzato, verificare log di sistema/supervisore per determinare se sia intervenuto un restart aggiuntivo non documentato tra la stesura del report di attivazione e la ripresa di questa sessione.
- **Classificazione**: OPERATIONAL TRACKING GAP, non un difetto del portale o del backend applicativo.

### 15. Instrument professionale — CODICE IMPLEMENTATO MA NON ATTIVO A RUNTIME (Patch 10D-B, 2026-07-05)
- **Severità**: INFO (stato atteso e intenzionale, non un difetto)
- **Impatto**: `backend/app/services/instrument_source_provider.py` ora include `ProfessionalInstrumentReadOnlyProvider` (provider read-only dry-run) e una factory `select_instrument_provider()` a 5 rami, verificati interamente offline (`py_compile`, import isolato, 4 scenari env, grep di sicurezza — tutti PASS). **Il backend 8090 in esecuzione non è stato riavviato**, quindi continua a servire il codice precedente a Patch 10D-B: il payload live resta esattamente quello di Patch 10C (nessuna chiave `schema_version`/`dry_run`/`provider`/`capabilities`/`dependencies`/`resource_policy`/`command_policy`), confermato con una verifica diretta del payload REST dopo l'implementazione.
- **Workaround**: nessuno necessario — comportamento runtime invariato per costruzione, nessuna regressione possibile finché il backend non viene riavviato.
- **Azione futura proposta**: `Patch 10D-C — Activation Restart` (restart controllato del solo backend 8090 per caricare il nuovo codice, mantenendo `RF_INSTRUMENT_ENABLE` non impostato/`0` di default, quindi `instrument_disabled` anche dopo il restart) — da autorizzare separatamente. Anche dopo un eventuale restart, qualunque acquisizione/misura reale resta vietata finché non sarà autorizzata una patch ulteriore con hardware reale disponibile e allowlist esplicita configurata.
- **Classificazione**: CODE READY / NOT YET ACTIVATED — coerente con il pattern già usato per Patch 9C (skeleton implementato, poi attivato separatamente con restart controllato).
- **Aggiornamento 2026-07-05 (Patch 10D-C)**: il codice è stato attivato a runtime con un restart controllato (PID `785527`→`799185`). Il payload live ora espone i campi additive-only (`schema_version`,`dry_run`,`provider`,`capabilities`,`dependencies`,`resource_policy`,`command_policy`), ma **resta `instrument_disabled`/safe** — nessuna variabile `RF_INSTRUMENT_*` impostata, nessun comportamento diverso da prima per qualunque consumer che non conosca i nuovi campi. Questa voce passa quindi da "CODE READY / NOT YET ACTIVATED" a **"CODE ACTIVE / STILL DISABLED BY DEFAULT"**.

### 16. Smoke test visivo browser (Playwright/Chromium) — NON DISPONIBILE in questo ambiente (2026-07-05)
- **Severità**: INFO/tracciamento operativo (non un difetto del portale)
- **Impatto**: dopo Patch 10D-C, il portale è stato verificato raggiungibile solo a livello HTTP (`curl`, tutte le route 200). Un vero controllo di regressione visiva (console error, network fail, canvas zero-size, overflow) come quello usato nelle Patch 7C-8C **non è stato eseguito**, perché `playwright-core` è presente in `node_modules` ma **senza binari Chromium scaricati**, e installarli sarebbe un'azione non autorizzata nei cicli 10D-C/checkpoint (vincolo esplicito "nessuna installazione").
- **Workaround**: nessuno in questo ciclo — verifica manuale dell'utente da browser reale confermata positiva ("tutti i portali sono riusciti/partono"), ma non sostituisce un test automatico strutturato.
- **Azione futura proposta**: se autorizzato, installare i browser Playwright (`npx playwright install chromium`, azione esplicitamente non coperta da questo ciclo) e ripetere gli script di verifica già usati in Patch 7C/8A/8B/8C sulle 4 route Vite/React.
- **Classificazione**: TEST COVERAGE GAP, non un difetto funzionale noto.

### 17. Rifiniture UI/UX non ri-verificate in questo checkpoint (2026-07-05)
- **Severità**: LOW/INFO
- **Impatto**: il checkpoint post-10D-C conferma che i portali sono raggiungibili e che il provider strumenti è attivo/safe, ma **non ri-verifica** in dettaglio eventuali rifiniture zoom/pan/contenuti o altre migliorie UI/UX già discusse in patch precedenti (7C/8A/8B/8C) — non essendo stato eseguito uno smoke test visivo in questo ciclo (vedi Limitation #16), nessuna regressione è stata cercata né esclusa oltre alla raggiungibilità HTTP.
- **Workaround**: nessuno necessario per il funzionamento di base, confermato dall'utente.
- **Azione futura proposta**: eventuale verifica visiva strutturata (Patch 10D-D o un ciclo dedicato), da autorizzare separatamente.
- **Classificazione**: NOT VERIFIED IN THIS CYCLE, non dichiarato né come bug né come regressione.
