# ADR-0004 — Worker Pattern per carichi scientifici CPU-bound

## Status
Accepted

## Decision
Le elaborazioni CPU-bound devono essere predisposte per ProcessPool / Task Queue. Il thread HTTP deve restituire task_id/correlation_id.
