import Foundation
import Ignite

struct TokfuelSite: Site {
    var name = "Tokfuel"
    var titleSuffix = " – Tokfuel"
    var description = "See what AI coding costs you, from the menu bar."
    var url = URL(static: "https://tokfuel.github.io")
    var favicon = URL(string: "images/app-icon.png")
    var useRelativePaths = true

    var homePage = Home()
    var layout = MainLayout()
}
