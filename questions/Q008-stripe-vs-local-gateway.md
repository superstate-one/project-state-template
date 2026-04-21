---
id: Q008
title: Should we use Stripe or a local payment gateway for rent collection?
status: open
raised: 2026-04-22
raised-by: kaloian
answered: null
answer-summary: null
related-features: [F003]
blocks-phase: spec
---

## The question

The client expressed interest in collecting rent "through the app" during
the prototype review. Before writing the backend plan we need to know
which payment processor to use.

## Options

- **Stripe**: team is familiar, reliable webhooks, supports recurring
  payments. Requires client to complete Stripe business onboarding.
  Fees: 1.4%–2.9% per transaction (EU rates).

- **Local Bulgarian payment gateway** (e.g. ePay, Borica): lower fees
  for domestic transactions, may be preferred by client's tenants who
  pay in BGN. Less team familiarity, longer integration time.

- **Outside the app** (no in-app payments): client invoices tenants
  manually or via bank transfer; app only records payment status.
  Simplest MVP option.

## Why it matters

This choice affects D002, the stripe integration entry, the backend
plan, and the scope of F003. The answer should come from the client
in the next meeting.

## What we need

Client decision on payment method before backend plan is written.
