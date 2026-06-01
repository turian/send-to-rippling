import Foundation

enum SMTPSecurity: String, CaseIterable, Identifiable {
    case starttls
    case ssl
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starttls: return "STARTTLS"
        case .ssl: return "SSL/TLS"
        case .none: return "None (cleartext)"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let smtpHost = "smtpHost"
        static let smtpPort = "smtpPort"
        static let smtpSecurity = "smtpSecurity"
        static let smtpUsername = "smtpUsername"
        static let senderName = "senderName"
        static let senderEmail = "senderEmail"
        static let defaultRecipient = "defaultRecipient"
    }

    @Published var smtpHost: String {
        didSet { defaults.set(smtpHost, forKey: Key.smtpHost) }
    }

    @Published var smtpPort: Int {
        didSet { defaults.set(smtpPort, forKey: Key.smtpPort) }
    }

    @Published var smtpSecurity: SMTPSecurity {
        didSet { defaults.set(smtpSecurity.rawValue, forKey: Key.smtpSecurity) }
    }

    @Published var smtpUsername: String {
        didSet { defaults.set(smtpUsername, forKey: Key.smtpUsername) }
    }

    @Published var senderName: String {
        didSet { defaults.set(senderName, forKey: Key.senderName) }
    }

    @Published var senderEmail: String {
        didSet { defaults.set(senderEmail, forKey: Key.senderEmail) }
    }

    @Published var defaultRecipient: String {
        didSet { defaults.set(defaultRecipient, forKey: Key.defaultRecipient) }
    }

    private init() {
        smtpHost = defaults.string(forKey: Key.smtpHost) ?? "smtp.gmail.com"
        let port = defaults.integer(forKey: Key.smtpPort)
        smtpPort = port == 0 ? 587 : port
        smtpSecurity = SMTPSecurity(rawValue: defaults.string(forKey: Key.smtpSecurity) ?? "")
            ?? .starttls
        smtpUsername = defaults.string(forKey: Key.smtpUsername) ?? ""
        senderName = defaults.string(forKey: Key.senderName) ?? ""
        senderEmail = defaults.string(forKey: Key.senderEmail) ?? ""
        defaultRecipient = defaults.string(forKey: Key.defaultRecipient) ?? "receipts@rippling.com"
    }

    var isConfigured: Bool {
        !smtpHost.isEmpty
            && !smtpUsername.isEmpty
            && !senderEmail.isEmpty
            && Keychain.shared.password(for: smtpUsername) != nil
    }
}
