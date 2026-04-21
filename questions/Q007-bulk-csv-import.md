---
id: Q007
title: Does the investor want bulk CSV import for apartments?
status: open
raised: 2026-04-09
raised-by: voice-agent
answered: null
answer-summary: null
related-features: [F002]
blocks-phase: spec
---

## The question

During the first meeting the investor mentioned "it would be amazing if
I could just upload a spreadsheet" when discussing adding apartments to a
building. They did not specify format, frequency, or whether this was a
must-have or nice-to-have.

## Why it matters

If yes: F002 needs CSV parsing logic, a file upload UI, and per-row
error handling. Significant scope increase.

If no: F002 simplifies to auto-generation of placeholder apartments from
the building's apartment count. Much smaller.

## What we need

Follow-up confirmation from client: Is CSV import required for MVP? If
yes, can they share a sample spreadsheet so we can validate column names
and formats before building the parser?
