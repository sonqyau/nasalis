import Foundation

struct TelemetryClient: Sendable {
    func fetchSnapshot() async -> TelemetrySnapshot {
        switch TelemetryBackend.current() {
        case .smcBridge:
            let smc = SMCReader().readTelemetry()

            var snapshot = TelemetrySnapshot(
                timestamp: Date(),
                telemetryError: nil,
                chargeLimitPercent: nil,
                batteryPercent: nil,
                isCharging: nil,
                designCapacity_mAh: nil,
                maxCapacity_mAh: nil,
                cycleCount: smc.batteryCycleCount,
                temperatureC: smc.batteryTemperatureC,
                serialNumber: nil,
                batteryVoltageV: smc.batteryVoltageV,
                batteryAmperageA: smc.batteryAmperageA,
                adapterVoltageV: smc.adapterVoltageV,
                adapterAmperageA: smc.adapterAmperageA,
                adapterPowerW: smc.adapterPowerW,
                systemLoadW: smc.systemLoadW,
                batteryPowerW: smc.batteryPowerW,
                )

            let smcHasAny =
                snapshot.batteryVoltageV != nil || snapshot.batteryAmperageA != nil || snapshot.batteryPowerW != nil ||
                snapshot.adapterVoltageV != nil || snapshot.adapterAmperageA != nil || snapshot.adapterPowerW != nil ||
                snapshot.systemLoadW != nil

            let batt = BattReader()
            do {
                async let unified = batt.fetchUnifiedTelemetry()
                async let limit = batt.fetchLimitPercent()
                async let charging = batt.fetchCharging()
                async let currentCharge = batt.fetchCurrentChargePercent()

                let t = try await unified
                let limitPercent = try await limit
                let isCharging = try await charging
                let percent = try await currentCharge

                let p = t.power

                snapshot.chargeLimitPercent = limitPercent
                snapshot.isCharging = snapshot.isCharging ?? isCharging
                snapshot.batteryPercent = snapshot.batteryPercent ?? percent
                snapshot.cycleCount = snapshot.cycleCount ?? p?.Battery.CycleCount

                snapshot.adapterVoltageV = snapshot.adapterVoltageV ?? p?.Adapter.InputVoltage
                snapshot.adapterAmperageA = snapshot.adapterAmperageA ?? p?.Adapter.InputAmperage
                snapshot.adapterPowerW = snapshot.adapterPowerW ?? p?.Calculations.ACPower
                snapshot.systemLoadW = snapshot.systemLoadW ?? p?.Calculations.SystemPower
                snapshot.batteryPowerW = snapshot.batteryPowerW ?? p?.Calculations.BatteryPower
            } catch {
                if !smcHasAny {
                    snapshot.telemetryError = "SMC and batt telemetry unavailable: \(BattReader.humanReadable(error: error))"
                }
            }

            let needsLegacy =
                snapshot.serialNumber == nil ||
                snapshot.designCapacity_mAh == nil ||
                snapshot.maxCapacity_mAh == nil ||
                snapshot.temperatureC == nil ||
                snapshot.cycleCount == nil ||
                snapshot.batteryPercent == nil ||
                snapshot.isCharging == nil

            if needsLegacy {
                async let legacyDetails = Readers.readBatteryDetails()
                async let iokitSummary = IOKitReader.readBatterySummary()

                let d = await legacyDetails
                let iokit = await iokitSummary

                snapshot.designCapacity_mAh = snapshot.designCapacity_mAh ?? d.designCapacity_mAh
                snapshot.maxCapacity_mAh = snapshot.maxCapacity_mAh ?? d.maxCapacity_mAh
                snapshot.serialNumber = snapshot.serialNumber ?? d.serialNumber
                snapshot.temperatureC = snapshot.temperatureC ?? d.temperatureC
                snapshot.cycleCount = snapshot.cycleCount ?? d.cycleCount

                snapshot.batteryVoltageV = snapshot.batteryVoltageV ?? d.batteryVoltageV
                snapshot.batteryAmperageA = snapshot.batteryAmperageA ?? d.batteryAmperageA
                snapshot.batteryPowerW = snapshot.batteryPowerW ?? d.batteryPowerW

                snapshot.batteryPercent = snapshot.batteryPercent ?? iokit.batteryPercent
                snapshot.isCharging = snapshot.isCharging ?? iokit.isCharging
            }

            let hasAny =
                snapshot.batteryPercent != nil || snapshot.isCharging != nil ||
                snapshot.designCapacity_mAh != nil || snapshot.maxCapacity_mAh != nil ||
                snapshot.cycleCount != nil || snapshot.temperatureC != nil || snapshot.serialNumber != nil ||
                snapshot.batteryVoltageV != nil || snapshot.batteryAmperageA != nil || snapshot.batteryPowerW != nil ||
                snapshot.adapterVoltageV != nil || snapshot.adapterAmperageA != nil || snapshot.adapterPowerW != nil ||
                snapshot.systemLoadW != nil || snapshot.chargeLimitPercent != nil

            if !hasAny {
                snapshot.telemetryError = "Telemetry unavailable"
            }

            return snapshot
        }
    }
}
