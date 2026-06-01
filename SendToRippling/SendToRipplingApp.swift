import SwiftUI
import AppKit

@main
struct SendToRipplingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene satisfies the App protocol's requirement for at least
        // one Scene and provides the ⌘, menu item. The actual window we use is
        // owned by AppDelegate so we can reliably open it programmatically.
        Settings { PreferencesWindow() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var reviewWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var didReceiveOpenEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Defer the "no PDF was passed" decision — open-document events arrive
        // shortly after finishLaunching, not before.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.didReceiveOpenEvent else { return }
            self.showPreferencesWindow()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveOpenEvent = true
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            showPreferencesWindow()
            return
        }
        showReviewWindow(for: url)
        if !AppSettings.shared.isConfigured {
            showPreferencesWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Review window

    private func showReviewWindow(for pdfURL: URL) {
        if let existing = reviewWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Send to Rippling"
        window.center()
        window.isReleasedWhenClosed = false
        let content = ReviewWindow(
            pdfURL: pdfURL,
            onFinished: { [weak self, weak window] in
                window?.close()
                self?.reviewWindow = nil
            },
            onOpenPreferences: { [weak self] in
                self?.showPreferencesWindow()
            }
        )
        window.contentView = NSHostingView(rootView: content)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reviewWindow = window
    }

    // MARK: - Preferences window

    private func showPreferencesWindow() {
        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Send to Rippling — Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesWindow())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.preferencesWindow = nil
        }
    }
}
