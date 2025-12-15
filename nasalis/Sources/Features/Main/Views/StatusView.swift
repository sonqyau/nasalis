import SwiftUI

struct StatusView: View {
    @ObservedObject private var output: MainState
    private let input: BatteryInput

    init(viewModel: MainViewModel) {
        output = viewModel.output
        input = viewModel.input
    }

    var body: some View {
        Image(systemName: output.batteryIconName)
            .imageScale(.large)
            .symbolRenderingMode(.hierarchical)
            .opacity(output.isLoading ? 0.6 : 1.0)
            .task {
                input.viewAppeared()
            }
            .onDisappear {
                input.viewDisappeared()
            }
            .accessibilityLabel(output.accessibilityText)
    }
}
