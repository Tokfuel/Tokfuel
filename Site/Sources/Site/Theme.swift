import Ignite

/// The subpath GitHub Pages serves this site under (see `TokfuelSite.url`).
/// `Link` targets don't get this prepended automatically the way generated
/// asset hrefs do, so every hand-written internal link needs it explicitly.
let sitePath = "/Tokfuel"

/// Visual tokens for the Tokfuel site. Follow `Site/DESIGN.ja.md`.
///
/// Note: pure `#000000` equals Ignite's `Color.default` (empty hex → white:0), so
/// theme generation skips `--bs-body-bg` for true black. Use near-black instead.
enum Brand {
    static let blue = Color(hex: "#0071E3")
    static let blueHover = Color(hex: "#0077ED")
    static let blueLight = Color(hex: "#2997FF")

    static let ink = Color(hex: "#1D1D1F")
    /// Slightly darker than Apple's caption gray so long body copy stays readable.
    static let secondaryText = Color(hex: "#6E6E73")
    static let hairline = Color(hex: "#D2D2D7")

    static let page = Color(hex: "#FFFFFF")
    static let section = Color(hex: "#F5F5F7")
    static let nav = Color(hex: "#000000")

    /// Near-black so Ignite emits `--bs-body-bg` (pure black is treated as default).
    static let darkPage = Color(hex: "#010101")
    static let darkSection = Color(hex: "#1D1D1F")
    static let darkInk = Color(hex: "#F5F5F7")
    static let darkSecondary = Color(hex: "#A1A1A6")

    static let hero = Color(hex: "#010101")
}

/// Light/dark theme pair: Apple-like neutrals and blue accent.
struct TokfuelTheme: Theme {
    var colorScheme: ColorScheme

    var accent: Color { colorScheme == .dark ? Brand.blueLight : Brand.blue }
    var link: Color { colorScheme == .dark ? Brand.blueLight : Brand.blue }
    var hoveredLink: Color { colorScheme == .dark ? Color(hex: "#64B5FF") : Brand.blueHover }

    var primary: Color { colorScheme == .dark ? Brand.darkInk : Brand.ink }
    var secondary: Color { colorScheme == .dark ? Brand.darkSecondary : Brand.secondaryText }
    var tertiary: Color { colorScheme == .dark ? Color(hex: "#6E6E73") : Color(hex: "#86868B") }

    var background: Color { colorScheme == .dark ? Brand.darkPage : Brand.page }
    var secondaryBackground: Color { colorScheme == .dark ? Brand.darkSection : Brand.section }
    var tertiaryBackground: Color { colorScheme == .dark ? Color(hex: "#2C2C2E") : Color(hex: "#E8E8ED") }
    var border: Color { colorScheme == .dark ? Color(hex: "#424245") : Brand.hairline }

    var emphasis: Color { colorScheme == .dark ? Color.white : Brand.ink }

    var linkDecoration: TextDecoration { .underline }
    var headingFontWeight: FontWeight { .bold }
}
