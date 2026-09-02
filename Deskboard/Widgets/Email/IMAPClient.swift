import Foundation
import Network

struct MailSummary: Identifiable, Equatable {
    let id: Int // sequence number
    var subject: String
    var from: String
    var date: Date?
    var unread: Bool
}

enum IMAPError: Error {
    case connectionFailed
    case badResponse(String)
    case loginFailed
}

/// Minimal read-only IMAP4rev1 client: LOGIN, EXAMINE INBOX, STATUS, FETCH
/// headers of the newest messages. Deliberately no third-party dependency —
/// this covers exactly what the mail widget needs.
final class IMAPClient {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var buffer = Data()
    private var tagCounter = 0

    init(host: String, port: UInt16 = 993) {
        self.host = host
        self.port = port
    }

    /// Fetches the newest `limit` message headers plus the unseen count.
    func fetchInbox(user: String, password: String, limit: Int = 10) async throws -> (mails: [MailSummary], unseen: Int) {
        try await connect()
        defer { close() }

        _ = try await readLine() // server greeting
        try await command("LOGIN \(quote(user)) \(quote(password))", failure: IMAPError.loginFailed)

        let examineLines = try await command("EXAMINE INBOX")
        var messageCount = 0
        for line in examineLines {
            if let match = line.firstMatch(of: /\* (\d+) EXISTS/) {
                messageCount = Int(match.1) ?? 0
            }
        }

        var unseen = 0
        for line in try await command("STATUS INBOX (UNSEEN)") {
            if let match = line.firstMatch(of: /UNSEEN (\d+)/) {
                unseen = Int(match.1) ?? 0
            }
        }

        guard messageCount > 0 else { return ([], unseen) }
        let low = max(1, messageCount - limit + 1)
        let mails = try await fetchHeaders(range: "\(low):\(messageCount)")
        _ = try? await command("LOGOUT")
        return (mails.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }, unseen)
    }

    // MARK: FETCH parsing

    private func fetchHeaders(range: String) async throws -> [MailSummary] {
        let tag = nextTag()
        try await send("\(tag) FETCH \(range) (FLAGS BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)])\r\n")

        var mails: [MailSummary] = []
        while true {
            let line = try await readLine()
            if line.hasPrefix("\(tag) ") {
                guard line.contains("OK") else { throw IMAPError.badResponse(line) }
                break
            }
            guard let match = line.firstMatch(of: #/^\* (\d+) FETCH /#) else { continue }
            let seq = Int(match.1) ?? 0
            let unread = !line.contains("\\Seen")

            // The header block follows as a literal: ... {123}\r\n<123 bytes>
            var header = ""
            if let sizeMatch = line.firstMatch(of: /\{(\d+)\}$/), let size = Int(sizeMatch.1) {
                header = String(decoding: try await read(count: size), as: UTF8.self)
            }
            mails.append(MailSummary(
                id: seq,
                subject: decodeEncodedWords(headerField("Subject", in: header)) .nonEmpty ?? "(no subject)",
                from: prettyFrom(decodeEncodedWords(headerField("From", in: header))),
                date: parseDate(headerField("Date", in: header)),
                unread: unread
            ))
        }
        return mails
    }

    private func headerField(_ name: String, in header: String) -> String {
        // Unfold continuation lines, then find the field.
        let unfolded = header
            .replacingOccurrences(of: "\r\n ", with: " ")
            .replacingOccurrences(of: "\r\n\t", with: " ")
        for line in unfolded.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix(name.lowercased() + ":") {
                return String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    /// "Max Mustermann <max@example.com>" → "Max Mustermann"; bare address stays.
    private func prettyFrom(_ raw: String) -> String {
        if let match = raw.firstMatch(of: /^"?([^"<]+?)"?\s*</) {
            return String(match.1).trimmingCharacters(in: .whitespaces)
        }
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
    }

    private func parseDate(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        // Strip trailing "(CEST)" style comments.
        let cleaned = raw.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "dd MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) { return date }
        }
        return nil
    }

    /// RFC 2047 encoded-words: =?charset?B|Q?...?=
    private func decodeEncodedWords(_ input: String) -> String {
        var result = input
        while let match = result.firstMatch(of: /=\?([^?]+)\?([BbQq])\?([^?]*)\?=/) {
            let charset = String(match.1).lowercased()
            let mode = String(match.2).uppercased()
            let payload = String(match.3)
            var decoded: String?
            let data: Data?
            if mode == "B" {
                data = Data(base64Encoded: payload)
            } else {
                let qp = payload
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: #"=([0-9A-Fa-f]{2})"#, with: "%$1", options: .regularExpression)
                data = qp.removingPercentEncoding.map { Data($0.utf8) }
            }
            if let data {
                let encoding: String.Encoding = charset.contains("8859") ? .isoLatin1 : .utf8
                decoded = String(data: data, encoding: encoding)
            }
            result = result.replacingCharacters(of: match.range, with: decoded ?? "?")
        }
        return result
    }

    // MARK: Protocol plumbing

    private func connect() async throws {
        let connection = NWConnection(
            host: .init(host),
            port: .init(rawValue: port)!,
            using: .tls
        )
        self.connection = connection
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var resumed = false
            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    cont.resume()
                case .failed, .cancelled:
                    resumed = true
                    cont.resume(throwing: IMAPError.connectionFailed)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
        }
    }

    private func close() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
    }

    private func nextTag() -> String {
        tagCounter += 1
        return "a\(tagCounter)"
    }

    /// Sends a command and collects untagged lines until the tagged reply.
    @discardableResult
    private func command(_ text: String, failure: Error? = nil) async throws -> [String] {
        let tag = nextTag()
        try await send("\(tag) \(text)\r\n")
        var lines: [String] = []
        while true {
            let line = try await readLine()
            if line.hasPrefix("\(tag) ") {
                guard line.hasPrefix("\(tag) OK") else {
                    throw failure ?? IMAPError.badResponse(line)
                }
                return lines
            }
            lines.append(line)
        }
    }

    private func send(_ text: String) async throws {
        guard let connection else { throw IMAPError.connectionFailed }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(text.utf8), completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    private func readLine() async throws -> String {
        while true {
            if let range = buffer.range(of: Data("\r\n".utf8)) {
                let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                return String(decoding: lineData, as: UTF8.self)
            }
            try await fill()
        }
    }

    private func read(count: Int) async throws -> Data {
        while buffer.count < count {
            try await fill()
        }
        let data = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(data)
    }

    private func fill() async throws {
        guard let connection else { throw IMAPError.connectionFailed }
        let chunk: Data = try await withCheckedThrowingContinuation { cont in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    cont.resume(returning: data)
                } else if isComplete {
                    cont.resume(throwing: IMAPError.connectionFailed)
                } else {
                    cont.resume(returning: Data())
                }
            }
        }
        buffer.append(chunk)
    }

    /// IMAP quoted string with escaped backslashes/quotes.
    private func quote(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }

    func replacingCharacters(of range: Range<String.Index>, with replacement: String) -> String {
        var copy = self
        copy.replaceSubrange(range, with: replacement)
        return copy
    }
}
