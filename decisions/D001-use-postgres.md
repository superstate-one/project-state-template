---
id: D001
title: Use PostgreSQL as the primary data store
status: accepted
date: 2026-04-15
affects: [backend]
---

## Context

The data model is fundamentally relational — buildings own apartments,
apartments are associated with tenants, and the portfolio dashboard
requires aggregate queries across all of them. The entity graph is
well-defined and stable.

## Decision

We will use PostgreSQL for the primary data store.

## Consequences

- SQL aggregates make portfolio dashboard queries straightforward.
- Backend developers on the team are already familiar with Postgres.
- Schema is stable enough that the flexibility of a document store
  is not needed.
- Foreign key constraints enforce entity relationships at the database
  level, reducing the risk of orphaned records.

## Provenance

- 2026-04-15: Backend planning session; lead dev proposed Postgres over
  MongoDB, team agreed unanimously given the relational data model.
