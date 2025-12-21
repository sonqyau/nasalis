import SwiftUI

struct MainView: View {
    @ObservedObject private var output: MainState
    private let input: BatteryInput
    private let viewModel: MainViewModel

    private static let frameSize = CGSize(width: 360, height: 0)
    private static let sectionPadding = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
    static let gridSpacing: (h: CGFloat, v: CGFloat) = (12, 8)
    static let gridPadding = EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        output = viewModel.output
        input = viewModel.input
    }

    var body: some View {
        let telemetry = output.currentTelemetry
        let hasError = output.error != nil

        return Form {
            Section {
                PowerFlowView(telemetry: telemetry)
                    .padding(Self.sectionPadding)
            } header: {
                PowerFlowHeader()
            }

            Section {
                TelemetryGridView(telemetry: telemetry, systemMetrics: output.systemMetrics)
                    .padding(Self.sectionPadding)
            } header: {
                TelemetryHeader(isLoading: output.isLoading)
            }

            if hasError {
                Section {
                    if let error = output.error {
                        ErrorView(error: error)
                    }
                } header: {
                    ErrorHeader()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: Self.frameSize.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
        .refreshable {
            input.refreshRequested()
        }
    }
}

private struct SystemMetricsHeader: View {
    var body: some View {
        Label("System Metrics", systemImage: "chart.line.uptrend.xyaxis")
    }
}

private struct SettingsHeader: View {
    var body: some View {
        Label("Settings", systemImage: "gearshape")
    }
}

private struct PowerFlowView: View {
    let telemetry: TelemetrySnapshot

    var body: some View {
        PowerView(
            adapterPowerW: telemetry.adapterPowerDouble,
            batteryPowerW: telemetry.batteryPowerDouble,
            systemLoadW: telemetry.systemLoadDouble,
            isBatteryCharging: telemetry.isBatteryCharging,
        )
    }
}

private struct PowerFlowHeader: View {
    var body: some View {
        Label("Power flow", systemImage: "bolt")
    }
}

private struct TelemetryHeader: View {
    let isLoading: Bool

    var body: some View {
        HStack {
            Label("Telemetry", systemImage: "gauge")
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
    }
}

private struct ErrorView: View {
    let error: NSError

    var body: some View {
        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            .foregroundColor(.red)
    }
}

private struct ErrorHeader: View {
    var body: some View {
        Label("Error", systemImage: "xmark.circle")
    }
}

private struct TelemetryGridView: View {
    let telemetry: TelemetrySnapshot
    let systemMetrics: SystemMetrics

    private var batteryPercent: Int? { telemetry.batteryPercentInt }
    private var isBatteryCharging: Bool { telemetry.isBatteryCharging }
    private var cycleCount: Int? { telemetry.cycleCountInt }
    private var temperature: Double? { telemetry.temperatureDouble }
    private var chargeLimitPercent: Int? { telemetry.chargeLimitPercentInt }
    private var maxCapacity: UInt16? { telemetry.maxCapacity_mAh }
    private var designCapacity: UInt16? { telemetry.designCapacity_mAh }

    private var batteryPowerAbs: Double? { telemetry.batteryPowerDouble.map(abs) }
    private var batteryCurrentAbs: Double? { telemetry.batteryAmperageA.map { abs(Double($0)) } }
    private var batteryVoltage: Double? { telemetry.batteryVoltageV.map(Double.init) }
    private var systemLoad: Double? { telemetry.systemLoadDouble }
    private var adapterPower: Double? { telemetry.adapterPowerDouble }
    private var adapterCurrent: Double? { telemetry.adapterAmperageA.map(Double.init) }
    private var adapterVoltage: Double? { telemetry.adapterVoltageV.map(Double.init) }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: MainView.gridSpacing.h, verticalSpacing: MainView.gridSpacing.v) {
            BatteryInfoRows(
                batteryPercent: batteryPercent,
                isBatteryCharging: isBatteryCharging,
                maxCapacity: maxCapacity,
                designCapacity: designCapacity,
                cycleCount: cycleCount,
                temperature: temperature,
                serialNumber: telemetry.serialNumber,
                chargeLimitPercent: chargeLimitPercent,
            )

            DividerRow()

            PowerMeasurementRows(
                batteryPower: batteryPowerAbs,
                batteryCurrent: batteryCurrentAbs,
                batteryVoltage: batteryVoltage,
                systemLoad: systemLoad,
                adapterPower: adapterPower,
                adapterCurrent: adapterCurrent,
                adapterVoltage: adapterVoltage,
            )

            DividerRow()

            SystemMetricsRows(systemMetrics: systemMetrics)
        }
        .padding(MainView.gridPadding)
    }
}

private struct SystemMetricsRows: View {
    let systemMetrics: SystemMetrics

    var body: some View {
        GridRow {
            TelemetryLabel.cpu
            TelemetryValue(text: FormattingUtils.percentage(systemMetrics.cpuUsage))
        }
        GridRow {
            TelemetryLabel.memory
            TelemetryValue(text: FormattingUtils.percentage(systemMetrics.memoryUsage))
        }
        if systemMetrics.network.totalBytesPerSecond > 0 {
            GridRow {
                TelemetryLabel.network
                TelemetryValue(text: systemMetrics.network.formattedBytesPerSecond(systemMetrics.network.totalBytesPerSecond) + "/s")
            }
        }
        if systemMetrics.disk.totalBytesPerSecond > 0 {
            GridRow {
                TelemetryLabel.disk
                TelemetryValue(text: systemMetrics.disk.formattedBytesPerSecond(systemMetrics.disk.totalBytesPerSecond) + "/s")
            }
        }
    }
}

private struct BatteryInfoRows: View {
    let batteryPercent: Int?
    let isBatteryCharging: Bool
    let maxCapacity: UInt16?
    let designCapacity: UInt16?
    let cycleCount: Int?
    let temperature: Double?
    let serialNumber: String?
    let chargeLimitPercent: Int?

    var body: some View {
        GridRow {
            TelemetryLabel.battery
            TelemetryValue(text: batterySummary)
        }
        GridRow {
            TelemetryLabel.health
            TelemetryValue(text: healthSummary)
        }
        GridRow {
            TelemetryLabel.cycle
            TelemetryValue(text: FormattingUtils.intString(cycleCount))
        }
        GridRow {
            TelemetryLabel.temperature
            TelemetryValue(text: FormattingUtils.tempString(temperature))
        }
        GridRow {
            TelemetryLabel.serial
            TelemetryValue(text: serialNumber ?? "--")
        }
        GridRow {
            TelemetryLabel.chargeLimit
            TelemetryValue(text: chargeLimitSummary)
        }
    }

    private var batterySummary: String {
        var parts: [String] = []
        if let batteryPercent { parts.append("\(batteryPercent)%") }
        parts.append(isBatteryCharging ? "Charging" : "Discharging")
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
    }

    private var healthSummary: String {
        guard let max = maxCapacity, let design = designCapacity, design > 0 else { return "--" }
        let health = (Double(max) / Double(design)) * 100
        return String(format: "%.0f%%  (%d/%d mAh)", health, max, design)
    }

    private var chargeLimitSummary: String {
        guard let v = chargeLimitPercent else { return "Requires batt daemon" }
        return "\(v)%"
    }
}

private struct PowerMeasurementRows: View {
    let batteryPower: Double?
    let batteryCurrent: Double?
    let batteryVoltage: Double?
    let systemLoad: Double?
    let adapterPower: Double?
    let adapterCurrent: Double?
    let adapterVoltage: Double?

    var body: some View {
        GridRow {
            TelemetryLabel.batteryPower
            TelemetryValue(text: FormattingUtils.watts(batteryPower))
        }
        GridRow {
            TelemetryLabel.batteryCurrent
            TelemetryValue(text: FormattingUtils.amps(batteryCurrent))
        }
        GridRow {
            TelemetryLabel.batteryVoltage
            TelemetryValue(text: FormattingUtils.volts(batteryVoltage))
        }

        DividerRow()

        GridRow {
            TelemetryLabel.systemLoad
            TelemetryValue(text: FormattingUtils.watts(systemLoad))
        }
        GridRow {
            TelemetryLabel.adapterPower
            TelemetryValue(text: FormattingUtils.watts(adapterPower))
        }
        GridRow {
            TelemetryLabel.adapterCurrent
            TelemetryValue(text: FormattingUtils.amps(adapterCurrent))
        }
        GridRow {
            TelemetryLabel.adapterVoltage
            TelemetryValue(text: FormattingUtils.volts(adapterVoltage))
        }
    }
}

private struct TelemetryLabel: View {
    let icon: String
    let text: String

    private static let iconFrame = CGSize(width: 18, height: 0)
    private static let spacing: CGFloat = 8
    private static let font = Font.subheadline
    private static let style = HierarchicalShapeStyle.secondary

    var body: some View {
        HStack(spacing: Self.spacing) {
            Image(systemName: icon)
                .frame(width: Self.iconFrame.width)
                .foregroundStyle(Self.style)
            Text(text)
                .font(Self.font)
                .foregroundStyle(Self.style)
        }
    }

    static let battery = Self(icon: "battery.100percent", text: "Battery")
    static let health = Self(icon: "percent", text: "Health")
    static let cycle = Self(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", text: "Cycle")
    static let temperature = Self(icon: "thermometer", text: "Temperature")
    static let serial = Self(icon: "note.text", text: "Serial")
    static let chargeLimit = Self(icon: "gauge.with.dots.needle.67percent", text: "Charge limit")
    static let batteryPower = Self(icon: "bolt", text: "Battery Power")
    static let batteryCurrent = Self(icon: "minus.plus.batteryblock", text: "Battery Current")
    static let batteryVoltage = Self(icon: "minus.plus.and.fluid.batteryblock", text: "Battery Voltage")
    static let systemLoad = Self(icon: "laptopcomputer", text: "System Load")
    static let adapterPower = Self(icon: "powerplug", text: "Adapter Power")
    static let adapterCurrent = Self(icon: "minus.plus.batteryblock", text: "Adapter Current")
    static let adapterVoltage = Self(icon: "minus.plus.and.fluid.batteryblock", text: "Adapter Voltage")
    static let cpu = Self(icon: "cpu", text: "CPU")
    static let memory = Self(icon: "memorychip", text: "Memory")
    static let network = Self(icon: "network", text: "Network")
    static let disk = Self(icon: "internaldrive", text: "Disk")
}

private struct TelemetryValue: View {
    let text: String

    private static let font = Font.subheadline
    private static let alignment = Alignment.trailing

    var body: some View {
        Text(text)
            .font(Self.font)
            .frame(maxWidth: .infinity, alignment: Self.alignment)
            .monospacedDigit()
    }
}

private struct DividerRow: View {
    var body: some View {
        GridRow {
            Divider().gridCellColumns(2)
        }
    }
}

private enum FormattingUtils {
    @inline(__always)
    static func intString(_ value: Int?) -> String {
        guard let value else { return "--" }
        return String(value)
    }

    @inline(__always)
    static func tempString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f °C", value)
    }

    @inline(__always)
    static func watts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f W", value)
    }

    @inline(__always)
    static func amps(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.3f A", value)
    }

    @inline(__always)
    static func volts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f V", value)
    }

    @inline(__always)
    static func percentage(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
