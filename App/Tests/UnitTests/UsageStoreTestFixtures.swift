import Foundation
@testable import TokfuelCore
@testable import TokfuelCursor
@testable import TokfuelCodex
@testable import TokfuelStore
@testable import TokfuelSettings

@MainActor
enum UsageStoreTestFixtures {
    static var defaultDrivers: [any CostDriver] {
        [CursorCostDriver(), CodexCostDriver()]
    }

    static func store(
        settings: AppSettings? = nil,
        defaults: UserDefaults = .standard,
        costDrivers: [any CostDriver]? = nil
    ) -> UsageStore {
        let drivers = costDrivers ?? defaultDrivers
        if let settings {
            return UsageStore(settings: settings, defaults: defaults, costDrivers: drivers)
        }
        return UsageStore(defaults: defaults, costDrivers: drivers)
    }
}
