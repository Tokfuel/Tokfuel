import Ignite

/// The subpath GitHub Pages serves this site under (see `TokfuelSite.url`).
/// `Link` targets don't get this prepended automatically the way generated
/// asset hrefs do, so every hand-written internal link needs it explicitly.
let sitePath = "/Tokfuel"

/// Tokfuel's accent color — an indigo close to the one Bajutsu's docs site uses,
/// so the two look like they belong to the same family of projects.
enum Brand {
    static let indigo = Color(hex: "#4F46E5")
    static let indigoLight = Color(hex: "#818CF8")
    static let indigoDark = Color(hex: "#4338CA")

    static let heroGradient = Gradient(
        colors: [Color(hex: "#4338CA"), Color(hex: "#4F46E5"), Color(hex: "#6D28D9")],
        type: .linear(angle: 135)
    )
}

/// A light/dark theme pair that keeps Bootstrap's default light/dark values for
/// everything (typography, spacing, backgrounds) and only recolors the accent —
/// every `Theme` property besides `colorScheme` already has a Bootstrap-matching
/// default via Ignite's `Theme` extension.
struct TokfuelTheme: Theme {
    var colorScheme: ColorScheme

    var accent: Color { Brand.indigo }
    var link: Color { colorScheme == .dark ? Brand.indigoLight : Brand.indigo }
    var hoveredLink: Color { colorScheme == .dark ? Color(hex: "#A5B4FC") : Brand.indigoDark }
}
