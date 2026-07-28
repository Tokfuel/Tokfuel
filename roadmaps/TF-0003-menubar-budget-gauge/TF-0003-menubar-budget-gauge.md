**English** · [日本語](TF-0003-menubar-budget-gauge-ja.md)

# TF-0003 — Menu-bar budget gauge (ring chart)

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0003](TF-0003-menubar-budget-gauge.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Menu bar & UX |
| Origin | Internal tester feedback (2026-07): "show budget usage as a pie chart so it doesn't crowd the menu bar" |
<!-- /TF-METADATA -->

## Introduction

Add a menu-bar display option that shows budget consumption as a compact ring (pie) gauge
instead of a text amount, so the status item stays icon-sized no matter how large the numbers get.

## Motivation

The current cost / remaining readouts are text (`⛽️ $12.34 · 月 $210`), which widens the status
item and crowds menu bars that are already full. Testers asked for an at-a-glance shape:
a ring that fills as the budget is consumed conveys "how close am I to the limit" in ~16 pt of
width, with no digits to read.

## Detailed design

- **Rendering.** Draw the status-item image with Core Graphics: a circular track with an arc
  filled to `spend / limit`, tinted like today's levels (template → orange at the warn
  threshold → red over the limit). Optionally keep a tiny fuel-pump glyph in the center.
- **Which budget.** Follow the same choice as the text modes: daily, monthly, or both
  (two concentric rings — inner day, outer month).
- **Settings.** One more option in the existing "メニューバー表示" radio list, with the same
  live-preview chip. Only selectable when at least one budget is set.
- **Fallbacks.** With no budget set (nothing to fill), fall back to the plain icon.

## Alternatives considered

- **Shorter text** (e.g. `62%`) — still text; a ring is smaller and faster to parse.
- **Gauge in the popover only** — the popover already has meter bars; the point is the
  always-visible menu bar.

## Progress

- [ ] Ring-drawing helper (single + concentric), unit-testable fill fraction → arc mapping
- [ ] `MenuBarDisplay` case + settings preview
- [ ] Level coloring consistent with `BudgetMonitor`

## References

- Feedback thread (internal, 2026-07-28)
