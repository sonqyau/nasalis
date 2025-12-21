import Foundation

enum ShellReader {
    static func readBatteryPercentAndCharging() async -> (Int?, Bool) {
        let output = await runProcess("/usr/bin/pmset", ["-g", "batt"], timeoutSeconds: 1.0) ?? ""

        let percent = parsePercent(output)

        let charging = if output.localizedCaseInsensitiveContains("charging") {
            true
        } else {
            false
        }

        return (percent, charging)
    }

    struct BatteryDetails: Sendable {
        var designCapacity_mAh: Int?
        var maxCapacity_mAh: Int?
        var cycleCount: Int?
        var temperatureC: Double?
        var serialNumber: String?
        var batteryVoltageV: Double?
        var batteryAmperageA: Double?
        var batteryPowerW: Double?
    }

    static func readBatteryDetails() async -> BatteryDetails {
        let output = await runProcess(
            "/usr/sbin/ioreg",
            [
                "-r",
                "-c",
                "AppleSmartBattery",
            ],
            timeoutSeconds: 1.0,
        ) ?? ""

        let designCapacity = parseKeyInt(output, key: "\"DesignCapacity\"")
        let maxCapacity = parseKeyInt(output, key: "\"AppleRawMaxCapacity\"")
        let cycleCount = parseKeyInt(output, key: "\"CycleCount\"")
        let temperatureRaw = parseKeyInt(output, key: "\"VirtualTemperature\"")

        let voltage_mV =
            parseKeyInt(output, key: "\"Voltage\"", allowSign: true)
                ?? parseKeyInt(output, key: "\"InstantVoltage\"", allowSign: true)

        let amperage_mA =
            parseKeyInt(output, key: "\"InstantAmperage\"", allowSign: true)
                ?? parseKeyInt(output, key: "\"Amperage\"", allowSign: true)
                ?? parseKeyInt(output, key: "\"InstantCurrent\"", allowSign: true)

        let serialNumber = parseKeyQuotedString(output, key: "\"Serial\"")

        let temperatureC: Double? = if let temperatureRaw {
            Double(temperatureRaw) / 100.0
        } else {
            nil
        }

        let batteryVoltageV: Double? = if let voltage_mV {
            Double(voltage_mV) / 1000.0
        } else {
            nil
        }

        let batteryAmperageA: Double? = if let amperage_mA {
            Double(amperage_mA) / 1000.0
        } else {
            nil
        }

        let batteryPowerW: Double? = if let v = batteryVoltageV, let a = batteryAmperageA {
            v * a
        } else {
            nil
        }

        return BatteryDetails(
            designCapacity_mAh: designCapacity,
            maxCapacity_mAh: maxCapacity,
            cycleCount: cycleCount,
            temperatureC: temperatureC,
            serialNumber: serialNumber,
            batteryVoltageV: batteryVoltageV,
            batteryAmperageA: batteryAmperageA,
            batteryPowerW: batteryPowerW,
        )
    }

    private static func runProcess(_ executablePath: String, _ arguments: [String], timeoutSeconds: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            actor State {
                var finished = false
                let continuation: CheckedContinuation<String?, Never>
                let process: Process
                let pipe: Pipe
                var timeoutTask: Task<Void, Never>?

                init(continuation: CheckedContinuation<String?, Never>, process: Process, pipe: Pipe) {
                    self.continuation = continuation
                    self.process = process
                    self.pipe = pipe
                }

                func armTimeout(seconds: TimeInterval) {
                    timeoutTask = Task.detached {
                        let ns = UInt64(seconds * 1_000_000_000)
                        if ns > 0 {
                            try? await Task.sleep(nanoseconds: ns)
                        }
                        await self.onTimeout()
                    }
                }

                func onTimeout() {
                    guard !finished else { return }
                    if process.isRunning {
                        process.terminate()
                    }
                }

                func onTerminate() {
                    guard !finished else { return }
                    finished = true
                    timeoutTask?.cancel()
                    timeoutTask = nil
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(bytes: data, encoding: .utf8))
                }

                func onStartFailed() {
                    guard !finished else { return }
                    finished = true
                    timeoutTask?.cancel()
                    timeoutTask = nil
                    continuation.resume(returning: nil)
                }
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let state = State(continuation: continuation, process: process, pipe: pipe)
            Task { await state.armTimeout(seconds: timeoutSeconds) }

            process.terminationHandler = { _ in
                Task { await state.onTerminate() }
            }

            do {
                try process.run()
            } catch {
                Task { await state.onStartFailed() }
            }
        }
    }

    @inline(__always)
    private static func parsePercent(_ s: String) -> Int? {
        s.utf8.withContiguousStorageIfAvailable { bytes -> Int? in
            let n = bytes.count
            var i = 0

            while i < n {
                if bytes[i] == 37 {
                    var j = i
                    var v = 0
                    var mul = 1
                    var digitCount = 0

                    while j > 0, digitCount < 3 {
                        j &-= 1
                        let d = Int(bytes[j]) - 48
                        guard d >= 0, d <= 9 else { break }
                        v &+= d * mul
                        mul &*= 10
                        digitCount &+= 1
                    }

                    if digitCount > 0 { return v }
                }
                i &+= 1
            }
            return nil
        } ?? fallbackParsePercent(s)
    }

    @inline(__always)
    private static func fallbackParsePercent(_ s: String) -> Int? {
        var accumulator = 0
        var hasDigits = false

        for byte in s.utf8 {
            if byte == 37 {
                return hasDigits ? accumulator : nil
            }

            let digit = Int(byte) - 48
            if digit >= 0, digit <= 9 {
                hasDigits = true
                accumulator = min(999, accumulator * 10 + digit)
            } else {
                hasDigits = false
                accumulator = 0
            }
        }
        return nil
    }

    @inline(__always)
    private static func parseKeyInt(_ s: String, key: String, allowSign: Bool = false) -> Int? {
        guard let keyRange = s.range(of: key) else { return nil }
        let tail = s[keyRange.upperBound...]

        let result = tail.utf8.withContiguousStorageIfAvailable { bytes -> (Int, Bool) in
            let n = bytes.count
            var i = 0

            while i < n, bytes[i] != 61 {
                i &+= 1
            }
            if i < n { i &+= 1 }

            while i < n, bytes[i] == 9 || bytes[i] == 10 || bytes[i] == 13 || bytes[i] == 32 {
                i &+= 1
            }

            guard i < n else { return (0, false) }

            let sign = (allowSign && bytes[i] == 45) ? -1 : 1
            if allowSign, bytes[i] == 45 || bytes[i] == 43 { i &+= 1 }

            var v = 0
            var digitCount = 0
            while i < n, digitCount < 10 {
                let d = Int(bytes[i]) - 48
                guard d >= 0, d <= 9 else { break }
                v = v &* 10 &+ d
                digitCount &+= 1
                i &+= 1
            }

            return digitCount > 0 ? (v * sign, true) : (0, false)
        }

        if let (value, success) = result, success {
            return value
        }
        return nil
    }

    private static func parseKeyQuotedString(_ s: String, key: String) -> String? {
        guard let keyRange = s.range(of: key) else { return nil }
        let tail = s[keyRange.upperBound...]
        guard let firstQuote = tail.firstIndex(of: "\"") else { return nil }
        let after = tail.index(after: firstQuote)
        guard let secondQuote = tail[after...].firstIndex(of: "\"") else { return nil }
        return String(tail[after ..< secondQuote])
    }
}
