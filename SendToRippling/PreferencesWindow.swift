import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var password: String = ""
    @State private var savedPassword: Bool = false
    @State private var showPassword: Bool = false

    init() {
        let stored = Keychain.shared.password(for: AppSettings.shared.smtpUsername) ?? ""
        _password = State(initialValue: stored)
    }

    var body: some View {
        Form {
            Section("SMTP server") {
                TextField("Host", text: $settings.smtpHost)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Port", value: $settings.smtpPort, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Picker("Security", selection: $settings.smtpSecurity) {
                        ForEach(SMTPSecurity.allCases) { sec in
                            Text(sec.displayName).tag(sec)
                        }
                    }
                }
                TextField("Username", text: $settings.smtpUsername)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                        .buttonStyle(.borderless)
                }
            }

            Section("Identity") {
                TextField("Your name", text: $settings.senderName)
                    .textFieldStyle(.roundedBorder)
                TextField("Sender email (From:)", text: $settings.senderEmail)
                    .textFieldStyle(.roundedBorder)
                Text("This must be an address Rippling has on file for you. Receipts are matched to your account by the From: header.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Destination") {
                TextField("Default recipient", text: $settings.defaultRecipient)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                if savedPassword {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Button("Save Password") {
                    let ok = Keychain.shared.setPassword(password, for: settings.smtpUsername)
                    savedPassword = ok
                }
                .disabled(settings.smtpUsername.isEmpty || password.isEmpty)
            }
            .padding(.top, 8)
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 520)
        .navigationTitle("Send to Rippling — Preferences")
    }
}
