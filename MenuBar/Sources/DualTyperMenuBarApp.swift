import AppKit
import SwiftUI
import DualTyperCore

@main
struct DualTyperMenuBarApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
    @StateObject private var controller = DualTyperController()

    var body: some Scene {
        Window("DualTyper", id: "setup") {
            SetupView(controller: controller)
                .frame(minWidth: 620, idealWidth: 680, minHeight: 470, idealHeight: 510)
                .modifier(TranslationSessionHostModifier(host: .shared))
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)

        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("DualTyper")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        presentSetupWindow(attempt: 0)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        presentSetupWindow(attempt: 0)
        return true
    }

    private func presentSetupWindow(attempt: Int) {
        let setupWindow = NSApp.windows.first { window in
            window.title == "DualTyper" && window.canBecomeKey
        }

        if let setupWindow {
            setupWindow.center()
            setupWindow.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }

        guard WindowPresentationRetryPolicy.shouldRetry(
            attempt: attempt,
            windowFound: setupWindow != nil
        ) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.presentSetupWindow(attempt: attempt + 1)
        }
    }
}

private struct SetupView: View {
    @ObservedObject var controller: DualTyperController

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 5) {
                    Text("DualTyper").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Free, on-device translation from your menu bar")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }

            permissionCard
            workflowCard

            HStack {
                if controller.accessibilityGranted {
                    Label("Accessibility enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Allow Accessibility") {
                        controller.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Open Privacy Settings") {
                        controller.openAccessibilitySettings()
                    }
                    .controlSize(.large)
                }
                Spacer()
                Button {
                    controller.refreshPermission()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh permission status")
            }

            Text(controller.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(28)
        .onAppear {
            controller.refreshPermission()
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("One explicit macOS permission", systemImage: "hand.raised.fill")
                .font(.headline)
            Text("DualTyper uses Accessibility only when you press its shortcut. It reads the selected text, translates it with Apple’s on-device Translation framework, verifies that your selection has not changed, and inserts the result. It does not continuously monitor or store your keystrokes.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private var workflowCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("How to use it").font(.headline)
            Label("Select a sentence in TextEdit, Notes, or another editable app.", systemImage: "selection.pin.in.out")
            Label("Press Control–Option–T.", systemImage: "keyboard")
            Label("Keep this setup window open or minimized while using DualTyper.", systemImage: "macwindow")
            Label("Keep the same app and selection active while translation completes.", systemImage: "checkmark.shield")
            Text("Target: \(controller.selectedLanguageName)")
                .fontWeight(.medium)
        }
        .padding(16)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var controller: DualTyperController

    var body: some View {
        Button("Open DualTyper…") {
            openWindow(id: "setup")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Text("Shortcut: Control–Option–T")
        Text(controller.accessibilityGranted ? "Accessibility enabled" : "Accessibility required")
        Divider()
        Menu("Translate to \(controller.selectedLanguageName)") {
            ForEach(DualTyperController.languages) { language in
                Button {
                    controller.selectTarget(language.id)
                } label: {
                    if language.id == controller.selectedTarget {
                        Label(language.name, systemImage: "checkmark")
                    } else {
                        Text(language.name)
                    }
                }
            }
        }
        Button("Open Accessibility Settings…") {
            controller.openAccessibilitySettings()
        }
        Text(controller.isBusy ? "Translating…" : controller.statusText)
        Divider()
        Button("Quit DualTyper") { NSApp.terminate(nil) }
    }
}
