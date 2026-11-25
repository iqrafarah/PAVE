import Foundation

/// A TLS connection to a mail server, line by line. `URLSessionStreamTask` is used because it can switch an open
/// connection to TLS, which SMTP's STARTTLS needs.
final class MailConnection {
    private let task: URLSessionStreamTask
    private var buffer = Data()
    private var offset = 0
    private static let timeout: TimeInterval = 30
    /// Longer while IMAP IDLE waits for the server to say something.
    var readTimeout: TimeInterval = MailConnection.timeout

    init(host: String, port: Int, implicitTLS: Bool) {
        task = URLSession.shared.streamTask(withHostName: host, port: port)
        task.resume()
        if implicitTLS { task.startSecureConnection() }
    }

    deinit { task.cancel() }

    func startTLS() {
        task.startSecureConnection()
    }

    func close() {
        task.closeWrite()
        task.cancel()
    }

    func write(_ text: String) async throws {
        try await write(Data(text.utf8))
    }

    func write(_ data: Data) async throws {
        do {
            try await task.write(data, timeout: Self.timeout)
        } catch {
            throw EmailError.network
        }
    }

    /// One line without its CRLF.
    func readLine() async throws -> Data {
        var searchFrom = offset
        while true {
            if let newline = buffer[searchFrom...].firstIndex(of: 0x0A) {
                var end = newline
                if end > offset, buffer[end - 1] == 0x0D { end -= 1 }
                let line = Data(buffer[offset..<end])
                offset = newline + 1
                compact()
                return line
            }
            searchFrom = buffer.endIndex
            try await fill()
        }
    }

    func readBytes(_ count: Int) async throws -> Data {
        while buffer.count - offset < count { try await fill() }
        let bytes = Data(buffer[offset..<(offset + count)])
        offset += count
        compact()
        return bytes
    }

    /// Drops what was read once it is most of the buffer, so reading a large message stays linear.
    private func compact() {
        guard offset > 64 * 1024, offset * 2 > buffer.count else { return }
        buffer = Data(buffer[offset...])
        offset = 0
    }

    private func fill() async throws {
        let chunk: Data?
        let isEnd: Bool
        do {
            (chunk, isEnd) = try await task.readData(ofMinLength: 1, maxLength: 256 * 1024, timeout: readTimeout)
        } catch {
            throw EmailError.network
        }
        if let chunk, !chunk.isEmpty {
            buffer.append(chunk)
        } else if isEnd {
            throw EmailError.network
        }
    }
}
