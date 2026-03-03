import SwiftUI
import ComposableArchitecture
import OpenClawCore

@main
struct FeedDeckApp: App {
    init() {
        KeychainHelper.service = "com.openclaw.feeddeck"
    }

    var body: some Scene {
        WindowGroup {
            FeedAggregatorView(
                store: Store(initialState: FeedAggregatorFeature.State()) {
                    FeedAggregatorFeature()
                }
            )
        }
    }
}
