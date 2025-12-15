import SwiftUI

struct MainView: View {
    @ObservedObject private var output: MainState
    private let input: BatteryInput

    init(viewModel: MainViewModel) {
        output = viewModel.output
        input = viewModel.input
    }

    var body: some View {
        Form {
            Section {
                PowerFlowView(telemetry: output.telemetry)
                    .padding(.vertical, 4)
            } header: {
                Label("Power flow", systemImage: "bolt")
            }

            Section {
                TelemetryGridView(telemetry: output.telemetry)
                    .padding(.vertical, 4)
            } header: {
                HStack {
                    Label("Telemetry", systemImage: "gauge")
                    Spacer()
                    if output.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }

            if let error = output.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                } header: {
                    Label("Error", systemImage: "xmark.circle")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
        .refreshable {
            input.refreshRequested()
        }
    }
}

private struct PowerFlowView: View {
    let telemetry: TelemetrySnapshot

    var body: some View {
        PowerView(
            adapterPowerW: telemetry.adapterPowerW,
            batteryPowerW: telemetry.batteryPowerW,
            systemLoadW: telemetry.systemLoadW,
            isCharging: telemetry.isCharging,
            )
    }
}

private struct TelemetryGridView: View {
    let telemetry: TelemetrySnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                label("Battery")
                value(batterySummary)
            }
            GridRow {
                label("Health")
                value(healthSummary)
            }
            GridRow {
                label("Cycle")
                value(intString(telemetry.cycleCount))
            }
            GridRow {
                label("Temperature")
                value(tempString(telemetry.temperatureC))
            }
            GridRow {
                label("Serial")
                value(telemetry.serialNumber ?? "--")
            }

            GridRow {
                label("Charge limit")
                value(chargeLimitSummary)
            }

            DividerRow()

            GridRow {
                label("Battery Power")
                value(watts(absOrNil(telemetry.batteryPowerW)))
            }
            GridRow {
                label("Battery Current")
                value(amps(absOrNil(telemetry.batteryAmperageA)))
            }
            GridRow {
                label("Battery Voltage")
                value(volts(telemetry.batteryVoltageV))
            }

            DividerRow()

            GridRow {
                label("System Load")
                value(watts(telemetry.systemLoadW))
            }
            GridRow {
                label("Adapter Power")
                value(watts(telemetry.adapterPowerW))
            }
            GridRow {
                label("Adapter Current")
                value(amps(telemetry.adapterAmperageA))
            }
            GridRow {
                label("Adapter Voltage")
                value(volts(telemetry.adapterVoltageV))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func label(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(for: text))
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .monospacedDigit()
    }

    private func icon(for label: String) -> String {
        switch label {
        case "Battery": "battery.100percent"
        case "Health": "percent"
        case "Cycle": "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case "Temperature": "thermometer"
        case "Serial": "note.text"
        case "Charge limit": "gauge.with.dots.needle.67percent"
        case "Battery Power": "bolt"
        case "Battery Current": "minus.plus.batteryblock"
        case "Battery Voltage": "minus.plus.and.fluid.batteryblock"
        case "System Load": "laptopcomputer"
        case "Adapter Power": "powerplug"
        case "Adapter Current": "minus.plus.batteryblock"
        case "Adapter Voltage": "minus.plus.and.fluid.batteryblock"
        default: "info.circle"
        }
    }

    private var batterySummary: String {
        let percent = telemetry.batteryPercent
        let charging = telemetry.isCharging

        var parts: [String] = []
        if let percent { parts.append("\(percent)%") }
        if let charging {
            parts.append(charging ? "Charging" : "Discharging")
        }
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
    }

    private var healthSummary: String {
        guard
            let max = telemetry.maxCapacity_mAh,
            let design = telemetry.designCapacity_mAh,
            design > 0
        else {
            return "--"
        }

        let health = (Double(max) / Double(design)) * 100
        return String(format: "%.0f%%  (%d/%d mAh)", health, max, design)
    }

    private var chargeLimitSummary: String {
        guard let v = telemetry.chargeLimitPercent else {
            return "Requires batt daemon"
        }
        return "\(v)%"
    }

    private func intString(_ value: Int?) -> String {
        guard let value else { return "--" }
        return String(value)
    }

    private func tempString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f °C", value)
    }

    private func absOrNil(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return abs(value)
    }

    private func watts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f W", value)
    }

    private func amps(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.3f A", value)
    }

    private func volts(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f V", value)
    }
}

private struct DividerRow: View {
    var body: some View {
        GridRow {
            Divider().gridCellColumns(2)
        }
    }
}
