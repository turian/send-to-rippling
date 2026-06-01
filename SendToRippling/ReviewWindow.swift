import SwiftUI
import PDFKit

struct ReviewWindow: View {
    let pdfURL: URL
    let onFinished: () -> Void
    let onOpenPreferences: () -> Void

    @ObservedObject private var settings = AppSettings.shared

    @State private var recipient: String
    @State private var subject: String = ""
    @State private var memo: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    init(pdfURL: URL, onFinished: @escaping () -> Void, onOpenPreferences: @escaping () -> Void) {
        self.pdfURL = pdfURL
        self.onFinished = onFinished
        self.onOpenPreferences = onOpenPreferences
        _recipient = State(initialValue: AppSettings.shared.defaultRecipient)
        _subject = State(initialValue: Self.defaultSubject(for: pdfURL))
    }

    var body: some View {
        HSplitView {
            PDFPreview(url: pdfURL)
                .frame(minWidth: 380, idealWidth: 460)

            VStack(alignment: .leading, spacing: 16) {
                Text("Send to Rippling")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("From").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Preferences…", action: onOpenPreferences)
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                    if settings.senderEmail.isEmpty {
                        Text("Not set — open Preferences to configure")
                            .italic()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(fromDisplay)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("To").font(.caption).foregroundStyle(.secondary)
                    TextField("recipient@example.com", text: $recipient)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Subject").font(.caption).foregroundStyle(.secondary)
                    TextField("Receipt — short description", text: $subject)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Memo (optional)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $memo)
                        .font(.body)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack {
                    Button("Cancel") { onFinished() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    if isSending {
                        ProgressView().scaleEffect(0.7)
                    }
                    Button("Send") { send() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSend)
                }
            }
            .padding(20)
            .frame(minWidth: 360, idealWidth: 400)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var fromDisplay: String {
        if settings.senderName.isEmpty {
            return settings.senderEmail
        }
        return "\(settings.senderName) <\(settings.senderEmail)>"
    }

    private var canSend: Bool {
        !isSending
            && !recipient.isEmpty
            && !settings.senderEmail.isEmpty
            && !settings.smtpUsername.isEmpty
    }

    private func send() {
        isSending = true
        errorMessage = nil

        let request = SMTPSendRequest(
            pdfURL: pdfURL,
            pdfFilename: pdfURL.lastPathComponent.isEmpty ? "receipt.pdf" : pdfURL.lastPathComponent,
            recipient: recipient,
            subject: subject,
            bodyText: memo.isEmpty ? "Sent via Send to Rippling." : memo
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try SMTPSender.send(request)
                DispatchQueue.main.async {
                    isSending = false
                    onFinished()
                }
            } catch {
                DispatchQueue.main.async {
                    isSending = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static func defaultSubject(for pdfURL: URL) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Receipt — \(formatter.string(from: Date()))"
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
