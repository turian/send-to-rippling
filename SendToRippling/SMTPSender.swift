import Foundation

enum SMTPError: LocalizedError {
    case missingPassword
    case messageWriteFailed
    case curlFailed(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .missingPassword:
            return "No SMTP password is stored in Keychain. Open Preferences to set one."
        case .messageWriteFailed:
            return "Could not write the outgoing message to a temporary file."
        case .curlFailed(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "curl failed with exit code \(code)."
            }
            return "curl failed (exit code \(code)):\n\(trimmed)"
        }
    }
}

struct SMTPSendRequest {
    let pdfURL: URL
    let pdfFilename: String
    let recipient: String
    let subject: String
    let bodyText: String
}

enum SMTPSender {
    static func send(_ request: SMTPSendRequest) throws {
        let settings = AppSettings.shared

        guard let password = Keychain.shared.password(for: settings.smtpUsername) else {
            throw SMTPError.missingPassword
        }

        let messageURL = try writeMIMEMessage(request, settings: settings)
        defer { try? FileManager.default.removeItem(at: messageURL) }

        try runCurl(messageURL: messageURL, request: request, settings: settings, password: password)
    }

    // MARK: - MIME assembly

    private static func writeMIMEMessage(
        _ request: SMTPSendRequest,
        settings: AppSettings
    ) throws -> URL {
        let pdfData = try Data(contentsOf: request.pdfURL)
        let base64 = pdfData.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])

        let boundary = "----=_SendToRippling_\(UUID().uuidString)"
        let messageID = "<\(UUID().uuidString)@send-to-rippling.local>"
        let dateHeader = rfc5322Date()

        let fromHeader: String = {
            if settings.senderName.isEmpty {
                return settings.senderEmail
            }
            return "\(encodeHeaderWord(settings.senderName)) <\(settings.senderEmail)>"
        }()

        let subjectHeader = encodeHeaderText(request.subject.isEmpty ? "Receipt" : request.subject)

        var headers: [String] = []
        headers.append("From: \(fromHeader)")
        headers.append("To: \(request.recipient)")
        headers.append("Subject: \(subjectHeader)")
        headers.append("Date: \(dateHeader)")
        headers.append("Message-ID: \(messageID)")
        headers.append("MIME-Version: 1.0")
        headers.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")

        let crlf = "\r\n"
        var message = headers.joined(separator: crlf) + crlf + crlf

        message += "--\(boundary)\(crlf)"
        message += "Content-Type: text/plain; charset=utf-8\(crlf)"
        message += "Content-Transfer-Encoding: 8bit\(crlf)\(crlf)"
        message += request.bodyText
        if !request.bodyText.hasSuffix("\n") { message += crlf } else { message += "" }
        message += crlf

        message += "--\(boundary)\(crlf)"
        message += "Content-Type: application/pdf; name=\"\(request.pdfFilename)\"\(crlf)"
        message += "Content-Transfer-Encoding: base64\(crlf)"
        message += "Content-Disposition: attachment; filename=\"\(request.pdfFilename)\"\(crlf)\(crlf)"
        message += base64
        message += crlf

        message += "--\(boundary)--\(crlf)"

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("send-to-rippling-\(UUID().uuidString).eml")
        do {
            try message.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            throw SMTPError.messageWriteFailed
        }
        return tmpURL
    }

    // MARK: - curl invocation

    private static func runCurl(
        messageURL: URL,
        request: SMTPSendRequest,
        settings: AppSettings,
        password: String
    ) throws {
        let scheme: String
        switch settings.smtpSecurity {
        case .ssl: scheme = "smtps"
        case .starttls, .none: scheme = "smtp"
        }
        let url = "\(scheme)://\(settings.smtpHost):\(settings.smtpPort)"

        var args: [String] = [
            url,
            "--mail-from", settings.senderEmail,
            "--mail-rcpt", request.recipient,
            "--upload-file", messageURL.path,
            "--user", "\(settings.smtpUsername):\(password)",
            "--silent",
            "--show-error"
        ]
        if settings.smtpSecurity == .starttls {
            args.append("--ssl-reqd")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = args

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderr = String(
                data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            throw SMTPError.curlFailed(exitCode: process.terminationStatus, stderr: stderr)
        }
    }

    // MARK: - Header encoding

    private static func rfc5322Date() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: Date())
    }

    /// Encode a free-text header value with RFC 2047 if it contains non-ASCII.
    private static func encodeHeaderText(_ text: String) -> String {
        guard text.contains(where: { !$0.isASCII }) else { return text }
        let utf8 = text.data(using: .utf8) ?? Data()
        return "=?UTF-8?B?\(utf8.base64EncodedString())?="
    }

    /// Encode a display-name word (e.g. before an email address).
    private static func encodeHeaderWord(_ word: String) -> String {
        if word.contains(where: { !$0.isASCII }) {
            return encodeHeaderText(word)
        }
        if word.contains(where: { ",;<>\"".contains($0) }) {
            let escaped = word.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return word
    }
}
