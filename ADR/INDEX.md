# ADR index

[日本語](INDEX.ja.md)

Overview of Tokfuel architecture decisions. See [`README.md`](README.md) for how to write
one.

Update this table in the same PR when you add an ADR or change its status.

| ID | Title | Status | Summary | Links |
|----|-------|--------|---------|-------|
| 0001 | Keep app-related trees under App/ | Accepted | Fix app, Tests, TestDocs, and E2E under `App/` | [0001-app-tree.md](0001-app-tree/0001-app-tree.md) |
| 0002 | Split SPM targets by feature to shrink parallel-PR collisions | Proposed | Collisions and layer enforcement irreconcilable; take collisions | [0002-feature-spm-modules.md](0002-feature-spm-modules/0002-feature-spm-modules.md) |

## Status guide

- **Accepted**: in force
- **Proposed** / **Draft**: under discussion
- **Deprecated** / **Superseded** / **Rejected**: kept for history
