import TokamakDOM
import DemoUI

@main
struct TokfuelDemoMain {
    static func main() {
        DemoPopoverView(fixtures: .sample).mount(elementID: "app")
    }
}
