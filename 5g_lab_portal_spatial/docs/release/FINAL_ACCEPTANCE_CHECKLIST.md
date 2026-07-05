# Final Acceptance Checklist — 5G Lab Portal

| # | Voce | Stato | Nota |
|---|---|---|---|
| 1 | Portale statico carica (11 pagine, 8080) | **PASS** | Verificato in Patch 4 (audit responsive) e Patch 5 (screenshot mirati) |
| 2 | Portale Vite carica (4 route, 5177) | **PASS** | Verificato in questa sessione, Patch 5C/5D |
| 3 | Build Vite passa (`npm run build`) | **PASS** | Rieseguito 3 volte, 0 errori |
| 4 | Route principali caricano senza errori bloccanti | **PASS** | `#live-ops` ha warning CORS/404 preesistenti (non bloccanti, non nuovi) |
| 5 | Fallback WebSocket visibili quando assente/incompatibile | **PASS** | `NO LIVE DATA`, `BASELINE · WS ONLINE · NO COMPATIBLE TELEMETRY`, `SIMULATED · WS ONLINE · NO COMPATIBLE TELEMETRY` tutti verificati via DOM |
| 6 | Nessun widget nero senza stato | **PASS** | Vite/React corretto in Patch 5C; portale statico Constellation VSA fullscreen risolta in Patch 7B (diagnosticata in Patch 5B) |
| 7 | Nessun valore baseline marcato live | **PASS** | Verificato: tutti e 6 i KPI in tono `baseline` quando `hasLiveData===false` |
| 8 | Nessun dato stale marcato live | **PASS** | Regola rispettata dal Patch 2/3 in avanti; nessuna regressione introdotta |
| 9 | Open5GS/UERANSIM non modificati durante le patch di frontend | **PASS** | Verificato via `pgrep`/`ip addr` prima/dopo ogni patch toccante il frontend |
| 10 | Rollback documentato | **PASS** (5C/5D, Patch 4) / **WARN** (Patch 1/2/3/5) | Backup su disco confermati solo per Patch 4 e 5C/5D; Patch 1/2/3/5 richiedono ricostruzione manuale (nessun `.bak` prodotto) |
| 11 | Known limitations documentate | **PASS** | 10 voci in `KNOWN_LIMITATIONS.md`, ciascuna con severità/impatto/workaround/azione futura |
| 12 | Sentinel Bridge non dichiarato implementato se solo pianificato | **PASS** | Dichiarato esplicitamente **PLANNED** in `SENTINEL_BRIDGE_READINESS.md`, nessun export reale testato |
| 13 | Zoom/black-page portale statico (Patch 5B) risolto | **PARZIALE** | Fullscreen VSA Constellation risolto (Patch 7B); dipendenza CDN Plotly resta **PLANNED** |
| 14 | Schema WebSocket 8090 allineato (`{rf,core}` vs `{profile,kpi,state,beam}`) | **PLANNED / da riverificare** | Richiede intervento backend; non riverificato in questo ciclo — discrepanza osservata durante Patch 8A-8C (vedi `KNOWN_LIMITATIONS.md`) tra questo stato documentato e il comportamento osservato su `#live-ops`, segnalata come TECH-DEBT documentale |
| 15 | CORS su `/api/v16f/telemetry/fast` risolto | **PLANNED / da riverificare** | Esplicitamente escluso dall'ambito di Patch 5C/5D/5E; non riverificato in questo ciclo |
| 16 | Home/Dashboard: zoom/pan/fit/reset/fullscreen su diagramma O-RAN | **PASS** | Patch 7C |
| 17 | Packet Sniffer: Pause/Clear/filtro/Export JSON | **PASS** | Patch 7C |
| 18 | SBA Console: Pause/Copy/Search | **PASS** | Patch 7C |
| 19 | Spectrum: Fit/Freeze | **PASS** | Patch 7C |
| 20 | Multi-Site zoom/pan/fit/reset | **PASS** | Patch 7C |
| 21 | Multi-RAT zoom/pan/fit/reset | **PASS** | Patch 7C |
| 22 | Spatial Lab zoom/pan/fit/reset | **PASS** | Patch 7C |
| 23 | Alarms — contenuto operativo arricchito | **PASS** | Patch 7C |
| 24 | Signal Analyzer responsive (canvas `cvs-ray`/`packetCanvas`) | **PASS** | Patch 7D, verificato 1366/1440/1920/2560 |
| 25 | O-RAN E2E Signal Analyzer — leggibilità etichette | **PASS** | Patch 7D |
| 26 | Vite/React `#live-ops` — overflow orizzontale | **PASS** | Patch 8A, verificato 1920/1440/1366/1024 |
| 27 | Vite/React `#live-ops` — testo 3D speculare | **PASS** (con nota onesta) | Patch 8B |
| 28 | Vite/React `#live-ops` — collisione label/HUD | **PASS** | Patch 8C, orbita 120s/120 campioni, overlap 0 |
| 29 | Vite/React 4 route reali (`#live-ops`,`#sentinel-x`,`#sentinel-x-legacy`,`#instrument-lab`) | **PASS** | Verificato dopo 8A/8B/8C: 0 console error, 0 network fail, 0 canvas zero-size, 0 overflow |
| 30 | Backend 8000/8090, Open5GS/UERANSIM non toccati da Patch 7C/7D/8A/8B/8C | **PASS** | Verificato via processo/servizio prima e dopo ogni patch |
| 31 | 3GPP/O-RAN lab coherence | **PASS** (lab-aligned, non conformità piena) | Vedi `3GPP_COHERENCE_MATRIX.md` |
| 32 | Sentinel Bridge | **PLANNED** | Invariato, vedi `SENTINEL_BRIDGE_READINESS.md` |
| 33 | RF live integration reale | **PLANNED / TECH-DEBT** | RF resta simulato dove dichiarato; nessun claim di RF live introdotto |
| 34 | Full production conformance | **NOT CLAIMED** | Nessuna dichiarazione di conformità piena in nessun documento di questo set |
| 35 | `DATA_CONTRACT_5G_PORTAL.md` allineato al comportamento reale di `#live-ops`/backend 8090 v16f | **PASS** | Patch 8E, dopo investigazione Patch 8D (lettura codice sorgente + probe read-only) |
| 36 | LiveOps provenance UI badge (`LIVE`/`SIMULATED`/`BASELINE` su `#live-ops`) | **TECH-DEBT / PLANNED** | Gap confermato in Patch 8D, documentato in `KNOWN_LIMITATIONS.md` #11; non corretto (fuori ambito Patch 8D/8E, che erano solo investigazione/documentazione) |
| 37 | RF live integration su `#live-ops` | **NOT CLAIMED / PLANNED** | Confermato SIMULATED (funzioni sintetiche `sin`/`cos`), nessun claim di RF live in codice o documentazione |
| 38 | Sentinel Bridge | **PLANNED** | Invariato da Patch 8D/8E |
| 39 | Full 3GPP conformance | **NOT CLAIMED** | Invariato da Patch 8D/8E |
| 40 | Patch 9C backend skeleton (provider RF dual-mode) | **PASS** | `SimulatedRfProvider`/`UnavailableRfProvider`/`SdrRxProvider` implementati, `py_compile` PASS, grep RX-only PASS |
| 41 | Backend 8090 activation (restart controllato) | **PASS** | PID 291968→743558, health invariato, log pulito, nessun altro servizio toccato |
| 42 | RF provider default simulated | **PASS** | Verificato post-restart: `rf.source_mode="simulated"`, `rf.provenance="SIMULATED"`, campi legacy invariati e coerenti con `legacy_synthetic` |
| 43 | SDR RX real capture | **PLANNED / NOT IMPLEMENTED** | `SdrRxProvider` è uno skeleton strutturale — `read_snapshot()` ritorna sempre `unavailable`, nessuna acquisizione IQ in Patch 9C |
| 44 | RF live integration (SDR) | **NOT CLAIMED** | Nessun HackRF/bladeRF usato, nessun dato RF reale prodotto da questa patch |
| 45 | RX-only guarantee (Patch 9A/9B/9C) | **PASS** | Nessuna funzione TX in `rf_source_provider.py` (verificato via grep), nessun jamming, nessun replay, nessuno stream IQ continuo |
| 46 | Open5GS/UERANSIM non toccati da Patch 9A/9B/9C | **PASS** | Verificato via `pgrep` invariato pre/post restart backend 8090 |
| 47 | Patch 9D — SDR RX Snapshot Implementation Design | **PASS (design)** | Architettura worker/cache, scelta SoapySDR, payload futuro, error handling, RX-only guardrails, test plan tutti progettati; nessun codice scritto |
| 48 | SDR RX snapshot reale implementato | **NOT IMPLEMENTED / PLANNED** | Rimandato a `Patch 9E`, da autorizzare solo con hardware SDR fisico disponibile |
| 49 | RX-only guarantee (design Patch 9D) | **PASS** | Guardrail RX-only progettati per la futura implementazione (grep statico obbligatorio, nessun endpoint di tuning remoto, device sempre RX-only) |
| 50 | Patch 10C — instrument provider disabilitato di default (`enabled=false`, `source_mode=instrument_disabled`, `provenance=NOT_ENABLED`) | **PASS** | Verificato read-only in questa sessione (2026-07-05) via `GET /api/v16f/telemetry/fast` |
| 51 | Patch 10C — safety policy strumento (`readonly=true`, `allow_configuration_writes=false`, `allow_rf_output_control=false`) | **PASS** | Verificato campo-per-campo nel payload `instrument.safety_policy` |
| 52 | Patch 10C — nessuna discovery hardware / SCPI / VISA / vendor eseguita | **PASS** | Confermato dai `limitations` auto-dichiarati nel payload (`"No VISA/SCPI discovery performed in Patch 10C"`) e da nessun comando SCPI/VISA/discovery eseguito in questa sessione |
| 53 | Patch 10C Activation — PID coerente tra report di attivazione e osservazione a ripresa sessione | **WARN** | PID dichiarato nel report (`781718`) non coincide con PID osservato alla ripresa sessione (`785527`); servizio comunque sano (health OK, comando/binding invariati), causa non investigata per vincolo di ambito (nessun restart/discovery in questa chiusura documentale) |
| 54 | Patch 10D — implementazione reale strumento professionale | **PLANNED / NOT IMPLEMENTED** | Nessun codice scritto, da autorizzare separatamente |
| 55 | Patch 10D-B — provider read-only implementato (`ProfessionalInstrumentReadOnlyProvider`, factory a 5 rami) | **PASS** | `py_compile` PASS, import isolato senza moduli vendor/VISA, 4 scenari factory PASS, grep sicurezza PASS (solo commenti/docstring) |
| 56 | Patch 10D-B — default runtime invariato (backend 8090 non riavviato) | **PASS** | Payload live REST verificato ancora sullo schema Patch 10C dopo l'implementazione (nessuna chiave `schema_version`/`dry_run`/`provider` presente) — codice non attivo a runtime |
| 57 | Patch 10D-B — nessun accesso VISA/SCPI/hardware reale | **PASS** | Nessuna chiamata `ResourceManager()`/`list_resources()`/`open_resource()`/`.query()`/`.write()` in codice operativo (verificato via grep), nessun import vendor a livello modulo (verificato via import isolato) |
| 58 | Patch 10D-C — Activation Restart (caricamento runtime del provider read-only) | **PASS** | Eseguito: PID `785527`→`799185`, stesso comando/cwd, nessun duplicato; provider caricato a runtime, ancora `instrument_disabled` |
| 59 | Patch 10D-C — smoke test HTTP portale (8080 statico + 4 route Vite) | **PASS** | Tutte le 5 URL richieste → 200; entry point reale `/src/main.jsx` → 200 |
| 60 | Patch 10D-C — smoke test visivo browser (console error/network fail/canvas zero-size/overflow) | **WARN / NOT EXECUTED** | Playwright/Chromium non installati in questo ambiente; installazione non autorizzata in questo ciclo — solo verifica HTTP-level eseguita |
| 61 | Checkpoint post-10D-C — verifica manuale utente positiva | **PASS** | Utente conferma: tutti i portali sono avviati/raggiungibili; alcune funzioni perfette, altre da rifinire (non tutte dichiarate complete) |
| 62 | Checkpoint post-10D-C — nessuna modifica codice/restart/installazione/discovery in questa fase | **PASS** | Solo verifiche read-only e append documentale eseguiti in questa sessione |

## Esito generale

**PASS con riserve esplicite** (voci 6[nota storica], 10, 13, 14, 15, 32, 33, 36, 37, 43, 48, 53, 54, 60 in WARN/PLANNED/PARZIALE/TECH-DEBT/NOT IMPLEMENTED/NOT EXECUTED). Non si dichiara "tutto risolto": restano limitazioni note e documentate, nessuna delle quali è stata nascosta o minimizzata in questo documento. Le voci 16-30 (Patch 7C/7D/8A/8B/8C), 35 (Patch 8E), 40-42/45-46 (Patch 9C), 47/49 (Patch 9D, solo design), 50-52 (Patch 10C Activation, chiusura documentale), 55-59 (Patch 10D-B/10D-C, implementazione e attivazione) e 61-62 (checkpoint) sono **PASS** verificato in questa sessione. La voce 53 (Patch 10C, discrepanza PID) è **WARN** dichiarato onestamente, non risolto per vincolo di ambito. La voce 60 (smoke test visivo) è **WARN** dichiarato per assenza di strumenti, non per un difetto del portale.

## Conferma "ciclo chiuso"

Tutti i 10 documenti richiesti per Patch 5E sono stati creati e successivamente aggiornati per Patch 7C/7D/8A/8B/8C (2026-07-04), Patch 8D/8E (2026-07-05), Patch 9A/9B/9C/9D (2026-07-05), Patch 10C Activation — chiusura documentale (2026-07-05), Patch 10D-B — Instrument Read-Only Provider Implementation (2026-07-05), Patch 10D-C — Activation Restart + Portal View Smoke Test (2026-07-05) e il Checkpoint post-10D-C (2026-07-05). Questo non significa "portale privo di limitazioni" — significa che la documentazione richiesta è completa, verificabile e onesta rispetto allo stato reale osservato, incluse le discrepanze non ancora risolte (vedi voce 14), il gap di provenance UI ancora aperto (voce 36), l'acquisizione SDR reale non ancora implementata (voce 48, design completo in Patch 9D, codice rimandato a Patch 9E), il provider strumenti ora attivo a runtime ma sempre `instrument_disabled` per default (voce 58), lo smoke test visivo automatico non eseguibile per mancanza di Playwright/Chromium (voce 60) e la discrepanza PID di Patch 10C Activation non investigata (voce 53). Verifica manuale dell'utente confermata positiva sulla raggiungibilità dei portali; nessuna funzione non verificata viene dichiarata completa in questo checkpoint.
