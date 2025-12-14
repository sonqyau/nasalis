import Foundation

struct MainFeature: Sendable {
    let actions: ActionChannel<MainAction>

    let state: AsyncStream<AppState>
}
