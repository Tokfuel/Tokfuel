import Ignite

struct MainLayout: Layout {
    var body: some Document {
        PlainDocument {
            Head()
            Body {
                content
            }
        }
    }
}
