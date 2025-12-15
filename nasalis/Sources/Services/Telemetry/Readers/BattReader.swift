import Foundation
import Network

struct BattReader: Sendable {
    struct Options: Sendable {
        var socketPath: String = "/var/run/batt.sock"
        var timeoutSeconds: TimeInterval = 1.0
    }

    enum ClientError: Error {
        case timeout
        case socketNotFound
        case invalidHTTPResponse
        case nonOKStatus(Int)
        case missingBody
        case decodeFailed
    }

    static func humanReadable(error: Error) -> String {
        if let e = error as? ClientError {
            switch e {
            case .timeout:
                return "request timed out"
            case .socketNotFound:
                return "batt daemon socket not found (daemon not running)"
            case .invalidHTTPResponse:
                return "invalid HTTP response"
            case let .nonOKStatus(code):
                return "HTTP status \(code)"
            case .missingBody:
                return "HTTP response body missing"
            case .decodeFailed:
                return "JSON decode failed"
            }
        }

        if let posix = error as? POSIXError {
            if posix.code.rawValue == 50 {
                return "batt socket unavailable (daemon not running or permission denied)"
            }
            return "POSIX error: \(posix.code)"
        }

        return String(describing: error)
    }

    let options: Options

    private static let decoder = JSONDecoder()
    private static let queue = DispatchQueue(label: "nasalis.batt-daemon-client", qos: .userInitiated, attributes: .concurrent)

    init(options: Options = Options()) {
        self.options = options
    }

    @inline(__always)
    func fetchUnifiedTelemetry() async throws -> BattTelemetryResponse {
        try await requestJSON(path: "/telemetry", as: BattTelemetryResponse.self)
    }

    @inline(__always)
    func fetchLimitPercent() async throws -> Int {
        try await requestJSON(path: "/limit", as: Int.self)
    }

    @inline(__always)
    func fetchCurrentChargePercent() async throws -> Int {
        try await requestASCIIInt(path: "/current-charge")
    }

    @inline(__always)
    func fetchCharging() async throws -> Bool {
        try await requestASCIIBool(path: "/charging")
    }

    private func requestJSON<T: Decodable>(path: String, as _: T.Type) async throws -> T {
        let data = try await requestData(path: path)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw ClientError.decodeFailed
        }
    }

    private func requestString(path: String) async throws -> String {
        let data = try await requestData(path: path)
        guard let s = String(bytes: data, encoding: .utf8) else {
            throw ClientError.decodeFailed
        }
        return s
    }

    private func requestASCIIInt(path: String) async throws -> Int {
        let data = try await requestData(path: path)
        return parseASCIIInt(data) ?? 0
    }

    private func requestASCIIBool(path: String) async throws -> Bool {
        let data = try await requestData(path: path)
        return parseASCIIBool(data)
    }

    private func requestData(path: String) async throws -> Data {
        if path.isEmpty || path.utf8.contains(0x0D) || path.utf8.contains(0x0A) {
            throw ClientError.invalidHTTPResponse
        }

        let request = "GET \(path) HTTP/1.1\r\nHost: unix\r\nConnection: close\r\n\r\n"
        let requestData = Data(request.utf8)

        let conn = NWConnection(to: .unix(path: options.socketPath), using: .tcp)

        actor RequestState {
            private var didFinish = false
            private let conn: NWConnection
            private let continuation: CheckedContinuation<Data, Error>
            private var timeoutTask: Task<Void, Never>?

            init(conn: NWConnection, continuation: CheckedContinuation<Data, Error>) {
                self.conn = conn
                self.continuation = continuation
            }

            func armTimeout(seconds: TimeInterval) {
                timeoutTask = Task.detached {
                    let ns = UInt64(seconds * 1_000_000_000)
                    if ns > 0 {
                        try? await Task.sleep(nanoseconds: ns)
                    }
                    await self.finish(.failure(ClientError.timeout))
                }
            }

            func finish(_ result: Result<Data, Error>) {
                guard !didFinish else { return }
                didFinish = true
                timeoutTask?.cancel()
                timeoutTask = nil
                conn.cancel()
                continuation.resume(with: result)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let state = RequestState(conn: conn, continuation: continuation)

            Task { await state.armTimeout(seconds: options.timeoutSeconds) }

            conn.stateUpdateHandler = { nwState in
                Task {
                    switch nwState {
                    case let .failed(err):
                        if case let NWError.posix(posixErr) = err, posixErr == .ENOENT {
                            await state.finish(.failure(ClientError.socketNotFound))
                            return
                        }
                        await state.finish(.failure(err))
                    case .ready:
                        conn.send(content: requestData, completion: .contentProcessed { sendErr in
                            Task {
                                if let sendErr {
                                    await state.finish(.failure(sendErr))
                                    return
                                }

                                do {
                                    let bytes = try await receiveAll(from: conn)
                                    let body = try parseHTTPBody(bytes)
                                    await state.finish(.success(body))
                                } catch {
                                    await state.finish(.failure(error))
                                }
                            }
                        })
                    default:
                        break
                    }
                }
            }

            conn.start(queue: Self.queue)
        }
    }

    private func receiveAll(from conn: NWConnection) async throws -> Data {
        actor ReceiverState {
            var buffer = Data()
            var finished = false
            let continuation: CheckedContinuation<Data, Error>

            init(continuation: CheckedContinuation<Data, Error>) {
                self.continuation = continuation
            }

            func append(_ chunk: Data) {
                if buffer.isEmpty {
                    buffer.reserveCapacity(max(4096, chunk.count * 2))
                }
                buffer.append(chunk)
            }

            func finishSuccess() {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: buffer)
            }

            func finishFailure(_ error: Error) {
                guard !finished else { return }
                finished = true
                continuation.resume(throwing: error)
            }

            func receiveNext(_ conn: NWConnection) {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
                    Task {
                        if let error {
                            await self.finishFailure(error)
                            return
                        }
                        if let content {
                            await self.append(content)
                        }
                        if isComplete {
                            await self.finishSuccess()
                        } else {
                            await self.receiveNext(conn)
                        }
                    }
                }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let state = ReceiverState(continuation: continuation)

            Task {
                await state.receiveNext(conn)
            }
        }
    }

    private func parseHTTPBody(_ data: Data) throws -> Data {
        let headerEnd = findHeaderEnd(data)
        guard headerEnd >= 0 else {
            throw ClientError.invalidHTTPResponse
        }

        let status = parseHTTPStatusCode(data, headerEnd: headerEnd)
        if status < 200 || status > 299 {
            throw ClientError.nonOKStatus(status)
        }

        let bodyStart = headerEnd + 4
        if bodyStart >= data.count {
            throw ClientError.missingBody
        }

        return data.subdata(in: bodyStart ..< data.count)
    }

    private func findHeaderEnd(_ data: Data) -> Int {
        if data.count < 4 { return -1 }
        return data.withUnsafeBytes { raw -> Int in
            guard let p = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            let n = raw.count
            var i = 0
            while i <= n - 4 {
                if p[i] == 13, p[i + 1] == 10, p[i + 2] == 13, p[i + 3] == 10 {
                    return i
                }
                i &+= 1
            }
            return -1
        }
    }

    private func parseHTTPStatusCode(_ data: Data, headerEnd: Int) -> Int {
        if headerEnd <= 0 { return 0 }
        return data.withUnsafeBytes { raw -> Int in
            guard let p = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            let n = min(headerEnd, raw.count)

            var i = 0
            while i < n, p[i] != 13, p[i] != 10 {
                i &+= 1
            }

            var firstSpace = -1
            var j = 0
            while j < i {
                if p[j] == 32 {
                    firstSpace = j
                    break
                }
                j &+= 1
            }
            if firstSpace < 0 { return 0 }

            var k = firstSpace + 1
            while k < i, p[k] == 32 {
                k &+= 1
            }
            if k + 2 >= i { return 0 }

            let d0 = Int(p[k]) - 48
            let d1 = Int(p[k + 1]) - 48
            let d2 = Int(p[k + 2]) - 48
            if (0 ... 9).contains(d0), (0 ... 9).contains(d1), (0 ... 9).contains(d2) {
                return d0 * 100 + d1 * 10 + d2
            }
            return 0
        }
    }

    @inline(__always)
    private func parseASCIIInt(_ data: Data) -> Int? {
        data.withUnsafeBytes { raw -> Int? in
            guard let p = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let n = raw.count

            var i = 0
            while i < n && (p[i] == 9 || p[i] == 10 || p[i] == 13 || p[i] == 32) {
                i &+= 1
            }

            guard i < n else { return nil }

            let sign = p[i] == 45 ? -1 : 1
            if p[i] == 45 || p[i] == 43 { i &+= 1 }

            var v = 0
            var digitCount = 0
            while i < n {
                let d = Int(p[i]) - 48
                guard d >= 0, d <= 9 else { break }
                guard digitCount < 9 else { break }
                v = v &* 10 &+ d
                digitCount &+= 1
                i &+= 1
            }

            return digitCount > 0 ? v * sign : nil
        }
    }

    @inline(__always)
    private func parseASCIIBool(_ data: Data) -> Bool {
        data.withUnsafeBytes { raw -> Bool in
            guard let p = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            let n = raw.count

            var i = 0
            while i < n, p[i] == 9 || p[i] == 10 || p[i] == 13 || p[i] == 32 {
                i &+= 1
            }

            guard i < n else { return false }

            let c0 = p[i]
            if c0 == 49 { return true }
            if c0 == 48 { return false }

            if i + 3 < n {
                let word = UInt32(p[i] | 0x20) |
                    (UInt32(p[i + 1] | 0x20) << 8) |
                    (UInt32(p[i + 2] | 0x20) << 16) |
                    (UInt32(p[i + 3] | 0x20) << 24)
                if word == 0x6575_7274 { return true }
            }

            if i + 4 < n {
                let word = UInt32(p[i] | 0x20) |
                    (UInt32(p[i + 1] | 0x20) << 8) |
                    (UInt32(p[i + 2] | 0x20) << 16) |
                    (UInt32(p[i + 3] | 0x20) << 24)
                let lastChar = p[i + 4] | 0x20
                if word == 0x736C_6166, lastChar == 101 { return false }
            }

            return false
        }
    }
}

struct BattTelemetryResponse: Decodable, Sendable {
    var power: BattPowerTelemetry?
}

struct BattPowerTelemetry: Decodable, Sendable {
    struct Adapter: Decodable, Sendable {
        var inputVoltage: Double?
        var inputAmperage: Double?
    }

    struct Battery: Decodable, Sendable {
        var cycleCount: Int?
    }

    struct Calculations: Decodable, Sendable {
        var ACPower: Double?
        var batteryPower: Double?
        var systemPower: Double?
        var healthByMaxCapacity: Int?
    }

    var adapter: Adapter
    var battery: Battery
    var calculations: Calculations
}
