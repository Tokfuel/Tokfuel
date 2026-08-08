# ADR (Architecture Decision Records)

[日本語](README.ja.md)

Keep technical decisions in the repo instead of scattering them across Issues and chat,
so later readers can recover *why* a shape was chosen.

Each ADR uses five sections: Decision, Context, Consideration, Consequences, and
References. ADRs live in this directory as git Markdown so OSS contributors and agents
share one source of truth.

For the full picture, see [`INDEX.md`](INDEX.md) ([日本語](INDEX.ja.md)).

## Layout

One decision = one directory. Japanese and English bodies live inside it.

```text
ADR/
  README.md / README.ja.md     # this guide
  INDEX.md / INDEX.ja.md       # catalog / overview
  TEMPLATE/                    # scaffold for a new ADR
    README.md / README.ja.md
  NNNN-slug/                   # one decision
    README.md / README.ja.md
```

| Path | Language |
|------|----------|
| `NNNN-slug/README.md` | English |
| `NNNN-slug/README.ja.md` | Japanese |

Both are required. If they drift, **the Japanese `README.ja.md` is canonical**; update the
English file to match. Keep `status` / `proposed` / `accepted` / `issue` identical in both
front matters.

Numbers increment by one from the highest existing id (zero-padded to 4 digits). A decision
is incomplete until both language files exist in that directory.

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

1. Copy [`TEMPLATE/`](TEMPLATE/) to `NNNN-slug/`
2. Title is a short decision sentence (verb-led)
3. Write Decision → Context → Consideration → Consequences → References
4. Consideration must include a **status-quo** option
5. Japanese body uses 常体 (plain form); English uses plain technical prose
6. Add a row to [`INDEX.md`](INDEX.md) / [`INDEX.ja.md`](INDEX.ja.md)
7. For agent-assisted drafts, use the [`write-adr`](../.agents/skills/write-adr/SKILL.md) skill

For large direction changes, discuss in a GitHub Issue (label `ADR 🏯`) first, then record
the agreement here.
