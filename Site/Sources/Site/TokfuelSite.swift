import Foundation
import Ignite

struct TokfuelSite: Site {
    var name = "Tokfuel"
    var titleSuffix = " – Tokfuel"
    var description = "See what AI coding costs you, from the menu bar."
    // GitHub Pages serves this repo under /Tokfuel/ (org page "tokfuel.github.io" is
    // a different, nonexistent repo; this one gets a project-page subpath). `url`
    // carries that subpath so Ignite's asset generation (CSS/JS/favicon) resolves
    // correctly on every page, not just the root. `useRelativePaths` has to be
    // false for the same reason: Ignite's relative mode always emits paths as if
    // the current page were at the site root, which breaks for any page besides
    // the homepage — see `sitePath` for the matching fix on hand-written `Link`s.
    var url = URL(static: "https://tokfuel.github.io/Tokfuel")
    var favicon = URL(string: "/images/app-icon.png")
    var useRelativePaths = false

    var homePage = Home()
    var layout = MainLayout()

    var lightTheme: (any Theme)? { TokfuelTheme(colorScheme: .light) }
    var darkTheme: (any Theme)? { TokfuelTheme(colorScheme: .dark) }

    @ElementBuilder<any StaticPage> var staticPages: [any StaticPage] {
        HomeJA()
        UsageGuideEN()
        ArchitectureEN()
        ADRIndexEN()
        TestingEN()
        PrivacyOverviewEN()
        RoadmapEN()
        UsageGuideJA()
        ArchitectureJA()
        ADRIndexJA()
        TestingJA()
        PrivacyOverviewJA()
        RoadmapJA()
    }
}
