# TRFMC Master Recovery and Completion Plan

## Stato
Il portale non va ulteriormente patchato. Va governato.

## Regola principale
Entrypoint ufficiale: `127.0.0.1:5173`.

## Sorgente ufficiale candidato
- `frontend/src/app/main.tsx`
- `frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx`
- `frontend/src/layout_orchestrator/EngineeringContentEnrichmentV49.tsx`
- `frontend/src/styles.css`

## Conteggi
- File Git modificati/non tracciati: 531
- Sorgenti React/CSS censiti: 64
- HTML pubblici censiti: 179
- Asset pubblici censiti: 224
- Residui V51 trovati: 10
- Placeholder/TODO/mock/stub trovati: 179
- Candidati promozione: 25
- Candidati archivio: 29

## Strategia
1. Freeze operativo.
2. Classificazione: OFFICIAL / PROMOTE / REVIEW / ARCHIVE.
3. Archiviazione non distruttiva dei residui e backup.
4. Ricostruzione shell in React.
5. Promozione dei migliori moduli public dentro la SPA.
6. Completamento per domini:
   - Mission Control
   - RF Physics
   - Signal Analyzer
   - RF/Microwave Engineering
   - Antenna System
   - Microwave Link
   - Fiber Optic
   - Private Networks
   - 5G Core/RAN
   - Data Center
   - Cyber RF Intelligence
   - Knowledge Base
7. QA finale: build, HTTP, screenshot, placeholder, navigation, API contract.

## Divieto operativo
Nessuna nuova patch runtime CSS/JS in `index.html`.
