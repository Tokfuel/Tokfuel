# ADR (Architecture Decision Records)

[日本語](README.ja.md)

Keep technical decisions in the repo instead of scattering them across Issues and chat,
so later readers can recover *why* a shape was chosen.

Each ADR uses five sections: Decision, Context, Consideration, Consequences, and
References. ADRs live in this directory as git Markdown so OSS contributors and agents
share one source of truth.

Operational docs: [`handbook/README.md`](../handbook/README.md) (index: [`README.md`](../README.md)).

## Catalog

Overview of Tokfuel architecture decisions. Update this table in the same PR when you
add an ADR or change its status.

| ID | Title | Status | Summary | Links |
|----|-------|--------|---------|-------|
| 0001 | Keep app-related trees under App/ | Accepted | Fix app and `App/Tests/` (UT/IT/TestDocs/E2E) under `App/` | [0001-app-tree.md](0001-app-tree/0001-app-tree.md) |
| 0002 | Split SPM targets into UI / Store / sources layers | Proposed | Match fetch → shape → present as UI → Store → sources | [0002-layer-spm-modules.md](0002-layer-spm-modules/0002-layer-spm-modules.md) |

### Catalog status guide

- **Accepted**: in force
- **Proposed** / **Draft**: under discussion
- **Deprecated** / **Superseded** / **Rejected**: kept for history

## Layout

One decision = one directory. Body filenames match the **directory name (ID-slug)**.

```text
Docs/adr/
  README.md / README.ja.md           # this guide and catalog
  TEMPLATE/                          # scaffold for a new ADR
    NNNN-slug.md / NNNN-slug.ja.md
  NNNN-slug/                         # one decision
    NNNN-slug.md / NNNN-slug.ja.md
```

Example: `Docs/adr/0001-app-tree/0001-app-tree.md` and `0001-app-tree.ja.md`

| Path | Language |
|------|----------|
| `NNNN-slug/NNNN-slug.md` | English |
| `NNNN-slug/NNNN-slug.ja.md` | Japanese |

Both are required. If they drift, **the Japanese `.ja.md` is canonical**; update the
English file to match. Keep `status` / `proposed` / `accepted` / `issue` identical in both
front matters.

Numbers increment by one from the highest existing id (zero-padded to 4 digits). Do not
count `TEMPLATE/`. A decision is incomplete until both language files exist in that
directory.

## Body status (`status`)

| Value | Meaning |
|-------|---------|
| `Draft` | Work in progress; not opened for review |
| `Proposed` | Ready for review |
| `Accepted` | Adopted |
| `Rejected` | Not adopted (kept for the record) |
| `Deprecated` | Was Accepted; no longer in force |
| `Superseded` | Replaced by another ADR (`supersedes` / successor in References) |

## Writing

1. Copy [`TEMPLATE/`](TEMPLATE/) to `NNNN-slug/`, then rename the scaffold `NNNN-slug.*` files
2. Title is a short decision sentence (verb-led)
3. Write Decision → Context → Consideration → Consequences → References
4. Consideration must include a **status-quo** option
5. Japanese body uses 常体 (plain form); English uses plain technical prose
6. Add a row to the catalog table in this README ([日本語](README.ja.md) table too)
7. For agent-assisted drafts, use the [`write-adr`](../../.agents/skills/write-adr/SKILL.md) skill

For large direction changes, discuss in a GitHub Issue (label `ADR 🏯`) first, then record
the agreement here.
