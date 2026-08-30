import Carbon.HIToolbox
import Foundation
import DualTyperCore

private let dualTyperHotKeySignature: OSType = 0x44545052 // DTPR

final class GlobalHotKeyMonitor {
    enum MonitorError: LocalizedError {
        case eventHandler(OSStatus)
        case registration(OSStatus)

        var errorDescription: String? {
            switch self {
            case .eventHandler(let status):
                return "Could not install the shortcut handler (\(status))."
            case .registration(let status):
                return "Control–Option–T is already used by another app (\(status))."
            }
        }
    }

    private let callbackRelay = SendableCallbackRelay()
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func start(action: @escaping @MainActor @Sendable () -> Void) throws {
        guard hotKey == nil else { return }
        callbackRelay.set {
            Task { @MainActor in action() }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let relay = Unmanaged<SendableCallbackRelay>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                relay.invoke()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(callbackRelay).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            throw MonitorError.eventHandler(handlerStatus)
        }

        let identifier = EventHotKeyID(signature: dualTyperHotKeySignature, id: 1)
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registrationStatus == noErr else {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            callbackRelay.clear()
            throw MonitorError.registration(registrationStatus)
        }
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        callbackRelay.clear()
    }
}
