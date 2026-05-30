# BASELINE RECOVERED AFTER P1D FAILURE

Timestamp: 20260530_131433

Status:
- P0B registry: PASS
- P0C Mission Control: PASS
- P1B RF Physics: PASS
- P1D route isolation: FAILED and frozen
- Runtime after restore: PASS

Runtime markers after restore:
- mission_p0b = 1
- mission_p0c = 1
- mission_p1b = 0
- mission_p1d = 0
- rf_p0b = 1
- rf_p0c = 1
- rf_p1b = 1
- rf_p1d = 0

Rule:
Do not patch MissionLayoutOrchestratorV42.tsx or main.tsx automatically for route isolation.
Next route isolation must be manually designed after source review.
