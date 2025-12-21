import SwiftUI

struct StatusView: View {
    @ObservedObject private var output: MainState
    private let input: BatteryInput

    private static let imageScale = Image.Scale.large
    private static let symbolMode = SymbolRenderingMode.hierarchical
    private static let loadingOpacity: Double = 0.6
    private static let normalOpacity: Double = 1.0

    init(viewModel: MainViewModel) {
        output = viewModel.output
        input = viewModel.input
    }

    var body: some View {
        let isLoading = output.isLoading
        let iconName = output.batteryIconName
        let accessibilityText = output.accessibilityText

        return Image(systemName: iconName)
            .imageScale(Self.imageScale)
            .symbolRenderingMode(Self.symbolMode)
            .opacity(isLoading ? Self.loadingOpacity : Self.normalOpacity)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .task {
                input.viewAppeared()
            }
            .onDisappear {
                input.viewDisappeared()
            }
            .accessibilityLabel(accessibilityText)
    }
}
