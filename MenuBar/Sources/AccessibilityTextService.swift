import AppKit
import ApplicationServices
import Carbon.HIToolbox
import DualTyperCore

private let accessibilityPromptOption = "AXTrustedCheckOptionPrompt"

struct AccessibleSelection {
    let element: AXUIElement
    let snapshot: TranslationSelectionSnapshot
}

enum AccessibilityTextServiceError: LocalizedError {
    case permissionRequired
    case noFocusedText
    case noSelectedText
    case unreadableSelection
    case secureField
    case selectionChanged
    case selectionNotEditable
    case insertionFailed(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Accessibility permission is required."
        case .noFocusedText:
            return "No editable text field is focused."
        case .noSelectedText:
            return "Select the sentence you want to translate, then press Control–Option–T."
        case .unreadableSelection:
            return "This app does not expose its text selection to macOS Accessibility."
        case .secureField:
            return "DualTyper never reads or translates secure text fields."
        case .selectionChanged:
            return "The app or selection changed while translating, so nothing was inserted."
        case .selectionNotEditable:
            return "This selection is not editable through macOS Accessibility."
        case .insertionFailed(let error):
            return "macOS could not insert the translation (Accessibility error \(error.rawValue))."
        }
    }
}

@MainActor
final class AccessibilityTextService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestPermission() -> Bool {
        AXIsProcessTrustedWithOptions(
            [accessibilityPromptOption: true] as CFDictionary
        )
    }

    func captureSelection(requireNonempty: Bool = true) throws -> AccessibleSelection {
        guard isTrusted else {
            throw AccessibilityTextServiceError.permissionRequired
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            throw AccessibilityTextServiceError.noFocusedText
        }

        let element = focusedValue as! AXUIElement
        guard !IsSecureEventInputEnabled(), !isSecureTextField(element) else {
            throw AccessibilityTextServiceError.secureField
        }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success else {
            throw AccessibilityTextServiceError.unreadableSelection
        }

        guard let selectedText = try selectedText(from: element) else {
            throw AccessibilityTextServiceError.unreadableSelection
        }
        if requireNonempty && !SelectionTranslationPlan.isValidSource(selectedText) {
            throw AccessibilityTextServiceError.noSelectedText
        }

        guard let range = try selectedRange(from: element) else {
            throw AccessibilityTextServiceError.unreadableSelection
        }

        return AccessibleSelection(
            element: element,
            snapshot: TranslationSelectionSnapshot(
                processIdentifier: processIdentifier,
                selectedText: selectedText,
                location: range.location,
                length: range.length
            )
        )
    }

    func replaceIfUnchanged(_ original: AccessibleSelection, with replacement: String) throws {
        let current = try captureSelection(requireNonempty: false)
        guard CFEqual(original.element, current.element),
              SelectionTranslationGuard.canApply(
                original: original.snapshot,
                current: current.snapshot
              ) else {
            throw AccessibilityTextServiceError.selectionChanged
        }

        let result = AXUIElementSetAttributeValue(
            original.element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFString
        )
        if result == .attributeUnsupported || result == .notImplemented {
            throw AccessibilityTextServiceError.selectionNotEditable
        }
        guard result == .success else {
            throw AccessibilityTextServiceError.insertionFailed(result)
        }
    }

    private func selectedText(from element: AXUIElement) throws -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )
        if result == .noValue || result == .attributeUnsupported {
            return nil
        }
        guard result == .success else {
            throw AccessibilityTextServiceError.unreadableSelection
        }
        return value as? String
    }

    private func isSecureTextField(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &value
        )
        let subrole = result == .success ? value as? String : nil
        return TextControlSecurityPolicy.isSecure(subrole: subrole)
    }

    private func selectedRange(from element: AXUIElement) throws -> CFRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )
        if result == .noValue || result == .attributeUnsupported {
            return nil
        }
        guard result == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AccessibilityTextServiceError.unreadableSelection
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range
    }
}
