import AppKit
import InputMethodKit

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "tech.zhuhroscar.DualTyper"
let connectionName = "\(bundleIdentifier)_Connection"
MainActor.assumeIsolated {
    AppleTranslationHost.shared.start()
}

let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
withExtendedLifetime(server) {
    NSApplication.shared.run()
}
