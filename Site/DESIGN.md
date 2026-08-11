# Site design rules

[日本語](DESIGN.ja.md)

Visual conventions for Tokfuel’s static site (Ignite). Inspired by Apple product
and documentation pages: generous whitespace, left alignment, system type, and a
blue CTA. Canonical tokens live in `Sources/Site/Theme.swift` and
`Assets/css/tokfuel.css`.

## Principles

1. **Left-aligned** — Body, headings, CTAs, and lists align start. No centered heroes.
2. **Whitespace first** — Wide section gaps, even rhythm. Don’t pack the viewport.
3. **Hierarchy via type** — Size and weight, not bordered cards or heavy shadows.
4. **Brand in the first viewport** — Tokfuel is the subject of the opening composition.
5. **Legibility over decoration** — Avoid gradient spam, glow, and emoji ornament.

## Color

| Role | Light | Dark | Notes |
|------|-------|------|-------|
| Page background | `#ffffff` | `#000000` | |
| Section surface | `#f5f5f7` | `#1d1d1f` | Apple gray band |
| Body text | `#1d1d1f` | `#f5f5f7` | |
| Secondary text | `#86868b` | `#a1a1a6` | |
| Accent / link / CTA | `#0071e3` | `#2997ff` | Apple-like blue |
| Nav | `#000000` | `#000000` | White label. Full-bleed via `Body.ignorePageGutters` + `NavigationBar.width(.viewport)` |
| Page ground (dark) | — | `#010101` | Pure `#000` equals Ignite `Color.default`, which drops `--bs-body-bg`; use near-black |
| Hairline | `#d2d2d7` | `#424245` | Only when needed |

No purple gradients or warm cream grounds.

## Typography

- Body and headings use the **system UI stack** (`-apple-system`,
  `BlinkMacSystemFont`, `"Helvetica Neue"`, sans-serif). Do not add Inter / Roboto.
- Code uses SF Mono / Menlo-like monospace.
- Headings are bold with slightly tight tracking. Body line-height ≈ 1.47.
- Docs measure ≈ **720px**. Marketing bands up to ≈ **980px**.

## Layout

- Every Ignite `VStack` must set **`alignment: .leading`** (default is center).
- Horizontal page padding ≈ 32px (tighten on narrow viewports in CSS).
- Docs: left sidebar + article. The current page stays a link marked `is-current` so tapping does not reflow the TOC.
- Japanese docs use BudouX (`budoux-ja`) for phrase-aware wrapping.
- Top nav uses Ignite `NavigationBar` (Bootstrap sticky navbar) and stays visible while scrolling.

## Top nav (skeptical choices)

Order: **Tokfuel · search field · language icon · theme icon · GitHub ★**.

| Item | Why | What we rejected |
|------|-----|------------------|
| Docs link | — | Extra Docs item; the brand already reaches home / docs via content |
| Search | Inline field in the nav; results drop down. `/` focuses it | Modal-opening Search link |
| Language icon | One click to the peer page (translate icon); tooltip shows English / 日本語 | Spelling out English / 日本語 in the bar |
| Theme icon | Toggle; moon → dark, sun → light | Separate Light / Dark text links |
| GitHub ★ | Standard OSS docs affordance; live star count | Dropping the link because the count is small |

Language icon goes to the peer page (home `/` ↔ `/ja`, docs topic ↔ topic). The brand logo returns to the matching-language home.

## Components

- **Top nav** — As in the table above.
- **Search** — Inline nav field + `Assets/js/search-index.json`. `/` focuses the field.
- **CTA** — Filled accent blue; moderate radius (no multi-layer shadows).
- **Links** — Underline or blue; slightly brighter/darker on hover.
- **Cards** — Default off. Thin surface or hairline only when interaction needs a box.
- **Hero media** — Real product screenshot, edge-aware. No collage or floating cards.

## Motion

- No flashy animation beyond theme switching. Prefer fades or short hover states.

## Checklist (new or changed pages)

- [ ] Main `VStack`s use `alignment: .leading`
- [ ] Generated HTML has no leftover centered headings/paragraphs
- [ ] Colors stay in the table (especially no purple gradients)
- [ ] JA docs still load BudouX via DocsLayout
- [ ] Internal links include `sitePath` (`/Tokfuel`)
