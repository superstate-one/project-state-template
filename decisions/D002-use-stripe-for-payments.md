---
id: D002
title: Use Stripe for payment processing
status: proposed
date: 2026-04-22
affects: [F003]
---

## Context

F003 (portfolio dashboard) needs to display rent payment status per
apartment. The client asked whether rent collection could happen
"through the app." The team needs to decide which payment provider
to use before the backend plan is written.

## Decision

Pending resolution of Q008 (Stripe vs local gateway). Current lean
is Stripe due to team familiarity, webhook reliability, and built-in
support for recurring payments.

## Consequences

- Stripe webhooks will drive payment status updates in the dashboard.
- Stripe fees apply per transaction; client needs to be informed.
- Stripe requires a business account — client must complete Stripe
  onboarding before go-live.
- If rejected in favour of a local gateway, this decision will be
  marked obsolete and a new D003 created.

## Provenance

- 2026-04-22: Proposed after prototype review; client mentioned rent
  collection via the app. Q008 raised to confirm client preference.
