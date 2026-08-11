import Ignite

struct ADRIndexEN: StaticPage {
    var path = "/docs/adr"
    var title = "ADR index — Tokfuel"
    var description = "Tokfuel architecture decisions. Read ADR-0001 and 0002 decisions, trade-offs, and consequences on this site."
    var layout: DocsLayout { DocsLayout(page: .adr, language: .en) }

    var body: some HTML {
        VStack(alignment: .leading, spacing: 24) {
            Text("ADR index").docsTitle()

            Text("""
            An ADR (Architecture Decision Record) keeps a technical decision in the repo \
            instead of scattering it across Issues and chat, so “why this shape” stays \
            discoverable later. Expand a section below to read Decision, background, \
            options, and consequences. The files under ADR/ in git are the bilingual \
            canonical source; when they diverge, Japanese wins.
            """)
            .foregroundStyle(.secondary)

            Text("Index").docsSubheading()

            List {
                ListItem {
                    Text("0001 — Keep app-related trees under App/ · Accepted · Issue #134")
                }
                ListItem {
                    Text("0002 — Split SPM targets into UI / Store / sources layers · Proposed · Issue #109")
                }
            }

            // MARK: ADR-0001

            Text("ADR-0001: Keep app-related trees under App/").docsSubheading()

            Text("Accepted · 2026-08-08 · Site out of scope · layout only, no behavior change")
                .font(.small)
                .foregroundStyle(.secondary)
                .class("tf-adr-status")

            Accordion {
                Item("Decision", startsOpen: true) {
                    Text("""
                    Fix the home for the app and verification artifacts as follows. Directories \
                    are renamed, not only moved — names like Sources / Tests read as “the whole \
                    repository’s sources,” which blurs scope.
                    """)
                    .foregroundStyle(.secondary)

                    CodeBlock {
                        """
                        App/
                          Tokfuel*          … executable and libraries (was Tokfuel/Sources)
                          Tests/
                            UnitTests/      … what swift test runs
                            IntegrationTests/ … integration (later)
                            TestDocs/       … scenario design (not executed)
                            E2E/            … end-to-end implementations (not under swift test)
                        """
                    }

                    Text("""
                    Keep the product tree separate from Site / Docs / Scripts. Leave room for \
                    TestDocs and E2E under the same App/ parent.
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("Background and problems") {
                    Text("""
                    App code lived in Tokfuel/Sources and tests in Tokfuel/Tests, referenced from \
                    a single SPM target. We needed in-repo homes for scenario design and end-to-end \
                    tests (#134). Putting those at the root or in separate trees multiplies “where \
                    do I look?” for app work.
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("Scattered homes make contributors hunt for the right place and mix unrelated changes in one PR.") }
                        ListItem { Text("Without a decided parent for TestDocs / E2E, ad-hoc conventions appear and clash with later module splits.") }
                        ListItem { Text("Root-level or Tokfuel/Sources names do not clearly mean “the product tree.”") }
                    }
                }

                Item("Options considered") {
                    List {
                        ListItem { Text("1 Status quo — TestDocs / E2E land elsewhere later; scatter and growth problems remain (rejected).") }
                        ListItem { Text("2 Top-level siblings — entry points align but sit next to Site / Docs (rejected).") }
                        ListItem { Text("3 Gather under App/ — one parent for app-related work; Site stays outside (adopted).") }
                    }

                    Text("""
                    Discoverability, room to grow TestDocs / E2E, and fit with #109 (module split) \
                    favor option 3. Migration needs path updates but no behavior change.
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("Consequences") {
                    List {
                        ListItem { Text("One discovery entry for app-related work: App/.") }
                        ListItem { Text("Directory boundary between ops trees and product code.") }
                        ListItem { Text("Later module work can stay scoped as “inside the app.”") }
                    }

                    Text("""
                    This decision does not cover relocating legal docs or renaming the repo root. \
                    Scope is App/ consolidation only. Full comparison tables live in the ADR files.
                    """)
                    .foregroundStyle(.secondary)
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            // MARK: ADR-0002

            Text("ADR-0002: Split SPM targets into UI / Store / sources layers").docsSubheading()

            Text("Proposed · 2026-08-08 · premise ADR-0001 · target boundaries, not another tree move")
                .font(.small)
                .foregroundStyle(.secondary)
                .class("tf-adr-status")

            Accordion {
                Item("Decision", startsOpen: true) {
                    Text("""
                    Stop using a single SPM target under App/. Split library targets by layer. \
                    Fix data flow and dependency direction as follows.
                    """)
                    .foregroundStyle(.secondary)

                    CodeBlock {
                        """
                        sources (Claude / Cursor / Codex / Budget …)  … fetch; expose APIs that yield data
                                ↓
                        Store                                        … reshape in feature-named files; aggregate for UI
                                ↓
                        UI                                           … render what Store provides

                        Dependencies: UI → Store → sources
                        Concrete wiring: App (executable)
                        """
                    }

                    List {
                        ListItem { Text("Split sources by fetch axis. Keep only cross-cutting types in a thin TokfuelCore.") }
                        ListItem { Text("In Store, keep source-specific shaping in feature-named files (e.g. CursorUsage.swift) and assemble what UI consumes.") }
                        ListItem { Text("UI sees Store (and thin display types) only — not SQLite, retok, or dashboard APIs.") }
                        ListItem { Text("Keep Firebase, retok resources, and sqlite3 inside the source / Analytics targets that use them.") }
                        ListItem { Text("Do not change product behavior or the ground rules (local-only data, zero setup, unmodified retok, optional python3, no new packages).") }
                    }

                    Text("""
                    Do not adopt feature-vertical splits that close UI pieces inside each source. \
                    The natural cut is fetch → shape → present. Splitting Claude / Cursor under \
                    sources is the lower layer only; UI and Store stay layered, not source-vertical.
                    """)
                    .foregroundStyle(.secondary)
                }

                Item("Where a change lands") {
                    List {
                        ListItem {
                            Text("Fix today’s Cursor cost — fetch in TokfuelCursor, shape in Store’s Cursor file, presentation-only tweaks in TokfuelUI.")
                        }
                        ListItem {
                            Text("Popover padding / shared layout — TokfuelUI only. Leave Store / sources alone if data is unchanged.")
                        }
                        ListItem {
                            Text("Cursor row data path — Cursor fetches → Store shapes → UsageStore-like aggregation → PopoverView-like display.")
                        }
                    }
                }

                Item("Background and problems") {
                    Text("""
                    After ADR-0001 gathered code under App/, there was still a single target: UI, \
                    Store, networking, and cost math shared one directory (#109). Feature-vertical \
                    splits were compared to reduce PR collisions, but real data flow is “sources \
                    fetch, Store shapes, UI presents,” and cross-cutting UI edits remain. That cut \
                    is a layer boundary.
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("Store / UI / driver roles are document-only; the compiler cannot enforce them.") }
                        ListItem { Text("It is hard to tell from directory names whether a change is fetch, shape, or present.") }
                        ListItem { Text("Cross-cutting UI work and source-specific fetch work collide in the same tree.") }
                    }
                }

                Item("Options considered") {
                    List {
                        ListItem { Text("1 Status quo — boundary and clarity problems remain (rejected).") }
                        ListItem { Text("2 Layers — matches data flow and UI cross-cuts; sources split underneath (adopted).") }
                        ListItem { Text("3 Feature-vertical — helps source collisions but fights “fix UI together” (rejected).") }
                        ListItem { Text("4 Many micro-layers — clarity cost too high for this size (rejected).") }
                        ListItem { Text("5 Hybrid — vertical plus layers doubles boundary management (rejected).") }
                    }
                }

                Item("Consequences and risks") {
                    List {
                        ListItem { Text("Compile-time detection when UI reaches for SQLite or retok internals.") }
                        ListItem { Text("Clear change stories: fetch in Cursor target, shape in Store’s Cursor file, look in UI.") }
                        ListItem { Text("Store / UI can stay hotspots — split by feature-named and screen-named files; keep PRs small.") }
                        ListItem { Text("Untangle reverse deps (e.g. BudgetMonitor → UI) with callbacks / protocols before cutting targets.") }
                    }
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            // MARK: process

            Text("How ADRs are written").docsSubheading()

            Accordion {
                Item("Format and status", startsOpen: true) {
                    Text("""
                    One decision = one directory. Body filenames match the directory’s ID-slug. \
                    Both Japanese (.ja.md) and English (.md) are required. Bodies use Decision / \
                    Context / Consideration / Consequences / References; Consideration always \
                    includes the status-quo option.
                    """)
                    .foregroundStyle(.secondary)

                    List {
                        ListItem { Text("Accepted — in force") }
                        ListItem { Text("Proposed / Draft — under discussion or review") }
                        ListItem { Text("Deprecated / Superseded / Rejected — kept for history") }
                    }

                    Text("""
                    Large direction changes start as a GitHub Issue (label ADR), then land as an \
                    ADR once agreed. When you add an ADR or change its status, update the INDEX in \
                    the same PR.
                    """)
                    .foregroundStyle(.secondary)
                }
            }
            .openMode(.all)
            .accordionStyle(.plain)
            .class("tf-adr-accordion")

            HStack(spacing: 16) {
                Link("Architecture", target: "\(sitePath)/docs/architecture")
                    .linkStyle(.underline(.heavy))
                Link("Tests & verification", target: "\(sitePath)/docs/testing")
                    .linkStyle(.underline(.heavy))
                Link("ADR/ (git canonical)", target: "https://github.com/Tokfuel/Tokfuel/tree/main/ADR")
                    .linkStyle(.underline(.heavy))
            }
        }
        .frame(maxWidth: 720)
        .class("tf-adr")
    }
}
