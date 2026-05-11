# Full Telco Skeleton Architecture

## Layer

1. API Gateway / Trust Boundary
2. Mission Orchestrator
3. Event Fabric / CloudEvents
4. Domain Services
5. Scientific Worker Layer
6. Data / Evidence Layer
7. Frontend Mission Console

## Domini iniziali

- mission
- events
- scientific_core
- network_fabric
- telco_mns
- assets
- access_trust
- soc_noc
- evidence
- restricted

## Regole

- Controller HTTP senza logica di business.
- Eventi CloudEvents-ready.
- Worker pattern per calcoli CPU-bound.
- Open5GS via API/SBA/WebUI backend, non MongoDB diretto.
- Restricted sempre LOCKED.
