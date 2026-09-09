# ADR-0002 — Backend Clean Architecture / DDD

## Status
Accepted

## Context
Router HTTP con logica di business incorporata causerebbero accoppiamento forte, scarsa testabilità e debito tecnico.

## Decision
Il backend viene strutturato per domini: api, schemas, services, repositories, domain.

## Consequences
Maggiore ordine, più file iniziali, migliore evoluzione verso microservizi.
