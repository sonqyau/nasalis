import Foundation

struct AppState: Sendable, Equatable {
    var telemetry: TelemetrySnapshot

    @inline(__always)
    init(telemetry: TelemetrySnapshot = .empty) {
        self.telemetry = telemetry
    }
}

struct TelemetrySnapshot: Sendable, Equatable {
    let timestamp: Date
    var batteryPercent: UInt8?
    var isCharging: Bool
    var chargeLimitPercent: UInt8?

    var adapterPowerW: Float32?
    var systemLoadW: Float32?
    var batteryPowerW: Float32?

    var batteryVoltageV: Float32?
    var batteryAmperageA: Float32?
    var adapterVoltageV: Float32?
    var adapterAmperageA: Float32?

    var designCapacity_mAh: UInt16?
    var maxCapacity_mAh: UInt16?
    var cycleCount: UInt16?
    var temperatureC: Float32?

    var telemetryError: String?
    var serialNumber: String?

    static let empty: TelemetrySnapshot = Self(
        timestamp: .distantPast,
        batteryPercent: nil,
        isCharging: false,
        chargeLimitPercent: nil,
        adapterPowerW: nil,
        systemLoadW: nil,
        batteryPowerW: nil,
        batteryVoltageV: nil,
        batteryAmperageA: nil,
        adapterVoltageV: nil,
        adapterAmperageA: nil,
        designCapacity_mAh: nil,
        maxCapacity_mAh: nil,
        cycleCount: nil,
        temperatureC: nil,
        telemetryError: nil,
        serialNumber: nil,
    )

    @inline(__always)
    static func create(
        timestamp: Date,
        batteryPercent: Int? = nil,
        isCharging: Bool = false,
        chargeLimitPercent: Int? = nil,
        adapterPowerW: Double? = nil,
        systemLoadW: Double? = nil,
        batteryPowerW: Double? = nil,
        batteryVoltageV: Double? = nil,
        batteryAmperageA: Double? = nil,
        adapterVoltageV: Double? = nil,
        adapterAmperageA: Double? = nil,
        designCapacity_mAh: Int? = nil,
        maxCapacity_mAh: Int? = nil,
        cycleCount: Int? = nil,
        temperatureC: Double? = nil,
        telemetryError: String? = nil,
        serialNumber: String? = nil,
    ) -> Self {
        Self(
            timestamp: timestamp,
            batteryPercent: batteryPercent.map { UInt8(clamping: $0) },
            isCharging: isCharging,
            chargeLimitPercent: chargeLimitPercent.map { UInt8(clamping: $0) },
            adapterPowerW: adapterPowerW.map(Float32.init),
            systemLoadW: systemLoadW.map(Float32.init),
            batteryPowerW: batteryPowerW.map(Float32.init),
            batteryVoltageV: batteryVoltageV.map(Float32.init),
            batteryAmperageA: batteryAmperageA.map(Float32.init),
            adapterVoltageV: adapterVoltageV.map(Float32.init),
            adapterAmperageA: adapterAmperageA.map(Float32.init),
            designCapacity_mAh: designCapacity_mAh.map { UInt16(clamping: $0) },
            maxCapacity_mAh: maxCapacity_mAh.map { UInt16(clamping: $0) },
            cycleCount: cycleCount.map { UInt16(clamping: $0) },
            temperatureC: temperatureC.map(Float32.init),
            telemetryError: telemetryError,
            serialNumber: serialNumber,
        )
    }

    @inline(__always)
    init(
        timestamp: Date,
        batteryPercent: UInt8?,
        isCharging: Bool,
        chargeLimitPercent: UInt8?,
        adapterPowerW: Float32?,
        systemLoadW: Float32?,
        batteryPowerW: Float32?,
        batteryVoltageV: Float32?,
        batteryAmperageA: Float32?,
        adapterVoltageV: Float32?,
        adapterAmperageA: Float32?,
        designCapacity_mAh: UInt16?,
        maxCapacity_mAh: UInt16?,
        cycleCount: UInt16?,
        temperatureC: Float32?,
        telemetryError: String?,
        serialNumber: String?,
    ) {
        self.timestamp = timestamp
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.chargeLimitPercent = chargeLimitPercent
        self.adapterPowerW = adapterPowerW
        self.systemLoadW = systemLoadW
        self.batteryPowerW = batteryPowerW
        self.batteryVoltageV = batteryVoltageV
        self.batteryAmperageA = batteryAmperageA
        self.adapterVoltageV = adapterVoltageV
        self.adapterAmperageA = adapterAmperageA
        self.designCapacity_mAh = designCapacity_mAh
        self.maxCapacity_mAh = maxCapacity_mAh
        self.cycleCount = cycleCount
        self.temperatureC = temperatureC
        self.telemetryError = telemetryError
        self.serialNumber = serialNumber
    }
}

extension TelemetrySnapshot {
    @inline(__always)
    var batteryPercentInt: Int? { batteryPercent.map(Int.init) }

    @inline(__always)
    var chargeLimitPercentInt: Int? { chargeLimitPercent.map(Int.init) }

    @inline(__always)
    var adapterPowerDouble: Double? { adapterPowerW.map(Double.init) }

    @inline(__always)
    var systemLoadDouble: Double? { systemLoadW.map(Double.init) }

    @inline(__always)
    var batteryPowerDouble: Double? { batteryPowerW.map(Double.init) }

    @inline(__always)
    var designCapacityInt: Int? { designCapacity_mAh.map(Int.init) }

    @inline(__always)
    var maxCapacityInt: Int? { maxCapacity_mAh.map(Int.init) }

    @inline(__always)
    var cycleCountInt: Int? { cycleCount.map(Int.init) }

    @inline(__always)
    var temperatureDouble: Double? { temperatureC.map(Double.init) }

    @inline(__always)
    mutating func setBatteryPercent(_ value: Int?) {
        batteryPercent = value.map { UInt8(clamping: $0) }
    }

    @inline(__always)
    mutating func setChargeLimitPercent(_ value: Int?) {
        chargeLimitPercent = value.map { UInt8(clamping: $0) }
    }

    @inline(__always)
    mutating func setCycleCount(_ value: Int?) {
        cycleCount = value.map { UInt16(clamping: $0) }
    }

    @inline(__always)
    mutating func setDesignCapacity(_ value: Int?) {
        designCapacity_mAh = value.map { UInt16(clamping: $0) }
    }

    @inline(__always)
    mutating func setMaxCapacity(_ value: Int?) {
        maxCapacity_mAh = value.map { UInt16(clamping: $0) }
    }
}
