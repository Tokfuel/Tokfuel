import Ignite

struct MainLayout: Layout {
    var body: some Document {
        PlainDocument {
            Head {
                MetaLink(href: "/css/tokfuel.css", rel: .stylesheet)
            }
            Body {
                content
            }
            .ignorePageGutters()
        }
    }
}
