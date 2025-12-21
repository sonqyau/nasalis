import Foundation

struct TelemetryClient: Sendable {
    func fetchSnapshot() async -> TelemetrySnapshot {
        await withTaskGroup(of: TelemetrySnapshot.self) { group in
            switch TelemetryBackend.current() {
            case .smcBridge:
                group.addTask {
                    let smc = SMCReader().readTelemetry()

                    var snapshot = TelemetrySnapshot.create(
                        timestamp: Date(),
                        batteryPercent: nil,
                        isBatteryCharging: false,
                        chargeLimitPercent: nil,
                        adapterPowerW: smc.adapterPowerW,
                        systemLoadW: smc.systemLoadW,
                        batteryPowerW: smc.batteryPowerW,
                        batteryVoltageV: smc.batteryVoltageV,
                        batteryAmperageA: smc.batteryAmperageA,
                        adapterVoltageV: smc.adapterVoltageV,
                        adapterAmperageA: smc.adapterAmperageA,
                        designCapacity_mAh: nil,
                        maxCapacity_mAh: nil,
                        cycleCount: smc.batteryCycleCount,
                        temperatureC: smc.batteryTemperatureC,
                        telemetryError: nil,
                        serialNumber: nil,
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

                        snapshot.setChargeLimitPercent(limitPercent)
                        snapshot.isBatteryCharging = snapshot.isBatteryCharging || isCharging
                        snapshot.setBatteryPercent(snapshot.batteryPercentInt ?? percent)
                        snapshot.setCycleCount(snapshot.cycleCountInt ?? p?.battery.cycleCount)

                        snapshot.adapterVoltageV = snapshot.adapterVoltageV ?? p?.adapter.inputVoltage.map(Float32.init)
                        snapshot.adapterAmperageA = snapshot.adapterAmperageA ?? p?.adapter.inputAmperage.map(Float32.init)
                        snapshot.adapterPowerW = snapshot.adapterPowerW ?? p?.calculations.ACPower.map(Float32.init)
                        snapshot.systemLoadW = snapshot.systemLoadW ?? p?.calculations.systemPower.map(Float32.init)
                        snapshot.batteryPowerW = snapshot.batteryPowerW ?? p?.calculations.batteryPower.map(Float32.init)
                    } catch {
                        if !smcHasAny {
                            snapshot.telemetryError = NSError(
                                domain: "NasalisTelemetryError",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "SMC and batt telemetry unavailable: \(BattReader.humanReadable(error: error))"],
                            )
                        }
                    }

                    let needsLegacy =
                        snapshot.serialNumber == nil ||
                        snapshot.designCapacity_mAh == nil ||
                        snapshot.maxCapacity_mAh == nil ||
                        snapshot.temperatureC == nil ||
                        snapshot.cycleCount == nil ||
                        snapshot.batteryPercent == nil ||
                        !snapshot.isBatteryCharging

                    if needsLegacy {
                        async let legacyDetails = ShellReader.readBatteryDetails()
                        async let iokitSummary = IOKitReader.readBatterySummary()

                        let d = await legacyDetails
                        let iokit = await iokitSummary

                        snapshot.setDesignCapacity(snapshot.designCapacityInt ?? d.designCapacity_mAh)
                        snapshot.setMaxCapacity(snapshot.maxCapacityInt ?? d.maxCapacity_mAh)
                        snapshot.serialNumber = snapshot.serialNumber ?? d.serialNumber
                        snapshot.temperatureC = snapshot.temperatureC ?? d.temperatureC.map(Float32.init)
                        snapshot.setCycleCount(snapshot.cycleCountInt ?? d.cycleCount)

                        snapshot.batteryVoltageV = snapshot.batteryVoltageV ?? d.batteryVoltageV.map(Float32.init)
                        snapshot.batteryAmperageA = snapshot.batteryAmperageA ?? d.batteryAmperageA.map(Float32.init)
                        snapshot.batteryPowerW = snapshot.batteryPowerW ?? d.batteryPowerW.map(Float32.init)

                        snapshot.setBatteryPercent(snapshot.batteryPercentInt ?? iokit.batteryPercent)
                        snapshot.isBatteryCharging = snapshot.isBatteryCharging || iokit.isBatteryCharging
                    }

                    let hasAny =
                        snapshot.batteryPercent != nil || snapshot.isBatteryCharging ||
                        snapshot.designCapacity_mAh != nil || snapshot.maxCapacity_mAh != nil ||
                        snapshot.cycleCount != nil || snapshot.temperatureC != nil || snapshot.serialNumber != nil ||
                        snapshot.batteryVoltageV != nil || snapshot.batteryAmperageA != nil || snapshot.batteryPowerW != nil ||
                        snapshot.adapterVoltageV != nil || snapshot.adapterAmperageA != nil || snapshot.adapterPowerW != nil ||
                        snapshot.systemLoadW != nil || snapshot.chargeLimitPercent != nil

                    if !hasAny {
                        snapshot.telemetryError = NSError(
                            domain: "NasalisTelemetryError",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Telemetry unavailable"],
                        )
                    }

                    return snapshot
                }
            }

            for await result in group {
                return result
            }

            return TelemetrySnapshot.empty
        }
    }
}
