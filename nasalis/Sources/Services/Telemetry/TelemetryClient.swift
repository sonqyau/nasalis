import Foundation

struct TelemetryClient: Sendable {
  func fetchSnapshot() async -> TelemetrySnapshot {
    await withTaskGroup(of: TelemetrySnapshot.self) { group in
      switch TelemetryBackend.current() {
      case .smcBridge:
        group.addTask {
          let smc = SMCReader().readTelemetry()
          var snapshot = withUnsafePointer(to: smc) { ptr in
            TelemetrySnapshot.create(
              timestamp: Date(),
              batteryPercent: nil,
              isBatteryCharging: false,
              chargeLimitPercent: nil,
              adapterPowerW: ptr.pointee.adapterPowerW,
              systemLoadW: ptr.pointee.systemLoadW,
              batteryPowerW: ptr.pointee.batteryPowerW,
              batteryVoltageV: ptr.pointee.batteryVoltageV,
              batteryAmperageA: ptr.pointee.batteryAmperageA,
              adapterVoltageV: ptr.pointee.adapterVoltageV,
              adapterAmperageA: ptr.pointee.adapterAmperageA,
              designCapacityMah: nil,
              maxCapacityMah: nil,
              cycleCount: ptr.pointee.batteryCycleCount,
              temperatureC: ptr.pointee.batteryTemperatureC,
              telemetryError: nil,
              serialNumber: nil,
            )
          }

          let hasSMCData =
            snapshot.batteryVoltageV != nil || snapshot.batteryAmperageA != nil
            || snapshot.batteryPowerW != nil || snapshot.adapterVoltageV != nil
            || snapshot.adapterAmperageA != nil || snapshot.adapterPowerW != nil
            || snapshot.systemLoadW != nil

          let battery = BattReader()
          do {
            async let unified = battery.fetchUnifiedTelemetry()
            async let limit = battery.fetchLimitPercent()
            async let charging = battery.fetchCharging()
            async let currentCharge = battery.fetchCurrentChargePercent()

            let t = try await unified
            let limitPercent = try await limit
            let isCharging = try await charging
            let percent = try await currentCharge

            let p = t.power

            snapshot.setChargeLimitPercent(limitPercent)
            snapshot.isBatteryCharging = snapshot.isBatteryCharging || isCharging
            snapshot.setBatteryPercent(snapshot.batteryPercentInt ?? percent)
            snapshot.setCycleCount(snapshot.cycleCountInt ?? p?.battery.cycleCount)

            snapshot.adapterVoltageV =
              snapshot.adapterVoltageV ?? p?.adapter.inputVoltage.map(Float32.init)
            snapshot.adapterAmperageA =
              snapshot.adapterAmperageA ?? p?.adapter.inputAmperage.map(Float32.init)
            snapshot.adapterPowerW =
              snapshot.adapterPowerW ?? p?.calculations.acPower.map(Float32.init)
            snapshot.systemLoadW =
              snapshot.systemLoadW ?? p?.calculations.systemPower.map(Float32.init)
            snapshot.batteryPowerW =
              snapshot.batteryPowerW ?? p?.calculations.batteryPower.map(Float32.init)
          } catch {
            if !hasSMCData {
              snapshot.telemetryError = NSError(
                domain: "NasalisTelemetryError",
                code: 1,
                userInfo: [
                  NSLocalizedDescriptionKey:
                    "SMC and battery telemetry unavailable: \(BattReader.humanReadable(error: error))"
                ],
              )
            }
          }

          let needsLegacy =
            snapshot.serialNumber == nil || snapshot.designCapacityMah == nil
            || snapshot.maxCapacityMah == nil || snapshot.temperatureC == nil
            || snapshot.cycleCount == nil || snapshot.batteryPercent == nil
            || !snapshot.isBatteryCharging

          if needsLegacy {
            async let legacyDetails = ShellReader.readBatteryDetails()
            async let iokitSummary = IOKitReader.readBatterySummary()

            let d = await legacyDetails
            let iokit = await iokitSummary

            snapshot.setDesignCapacity(snapshot.designCapacityInt ?? d.designCapacityMah)
            snapshot.setMaxCapacity(snapshot.maxCapacityInt ?? d.maxCapacityMah)
            snapshot.serialNumber = snapshot.serialNumber ?? d.serialNumber
            snapshot.temperatureC = snapshot.temperatureC ?? d.temperatureC.map(Float32.init)
            snapshot.setCycleCount(snapshot.cycleCountInt ?? d.cycleCount)

            snapshot.batteryVoltageV =
              snapshot.batteryVoltageV ?? d.batteryVoltageV.map(Float32.init)
            snapshot.batteryAmperageA =
              snapshot.batteryAmperageA ?? d.batteryAmperageA.map(Float32.init)
            snapshot.batteryPowerW = snapshot.batteryPowerW ?? d.batteryPowerW.map(Float32.init)

            snapshot.setBatteryPercent(snapshot.batteryPercentInt ?? iokit.batteryPercent)
            snapshot.isBatteryCharging = snapshot.isBatteryCharging || iokit.isBatteryCharging
          }

          let hasAny =
            snapshot.batteryPercent != nil || snapshot.isBatteryCharging
            || snapshot.designCapacityMah != nil || snapshot.maxCapacityMah != nil
            || snapshot.cycleCount != nil || snapshot.temperatureC != nil
            || snapshot.serialNumber != nil || snapshot.batteryVoltageV != nil
            || snapshot.batteryAmperageA != nil || snapshot.batteryPowerW != nil
            || snapshot.adapterVoltageV != nil || snapshot.adapterAmperageA != nil
            || snapshot.adapterPowerW != nil || snapshot.systemLoadW != nil
            || snapshot.chargeLimitPercent != nil

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
