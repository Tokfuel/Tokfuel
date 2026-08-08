# ADR (Architecture Decision Records)

[日本語](README.ja.md)

Keep technical decisions in the repo instead of scattering them across Issues and chat,
so later readers can recover *why* a shape was chosen.

Each ADR uses five sections: Decision, Context, Consideration, Consequences, and
References. ADRs live in this directory as git Markdown so OSS contributors and agents
share one source of truth.

## Japanese and English pair

Same convention as README / SECURITY: **ship English and Japanese as a pair**.

| Path | Language |
|------|----------|
| `NNNN-slug.md` | English |
| `NNNN-slug.ja.md` | Japanese |

Both are required. If they drift, **the Japanese (`.ja.md`) file is canonical**; update
the English file to match. Keep `status` / `proposed` / `accepted` / `issue` identical
in both front matters.

## Layout

| Path | Role |
|------|------|
| [`TEMPLATE.md`](TEMPLATE.md) / [`TEMPLATE.ja.md`](TEMPLATE.ja.md) | New-ADR scaffolds |
| `NNNN-slug.md` / `NNNN-slug.ja.md` | One decision (zero-padded 4-digit id + kebab-case) |

Numbers increment by one from the highest existing id. A decision is incomplete until both
language files exist for that number.

## Status (`status`)

| Value | Meaning |
|-------|---------|
| `Draft` | Work in progress; not opened for review |
| `Proposed` | Ready for review |
| `Accepted` | Adopted |
| `Rejected` | Not adopted (kept for the record) |
| `Deprecated` | Was Accepted; no longer in force |
| `Superseded` | Replaced by another ADR (`supersedes` / successor in References) |

## Writing

1. Copy [`TEMPLATE.md`](TEMPLATE.md) and [`TEMPLATE.ja.md`](TEMPLATE.ja.md) to
   `NNNN-slug.md` / `NNNN-slug.ja.md`
2. Title is a short decision sentence (verb-led)
3. Write Decision → Context → Consideration → Consequences → References
4. Consideration must include a **status-quo** option
5. Japanese body uses 常体 (plain form); English uses plain technical prose
6. For agent-assisted drafts, use the [`write-adr`](../.agents/skills/write-adr/SKILL.md) skill

For large direction changes, discuss in a GitHub Issue (label `ADR 🏯`) first, then record
the agreement here.
