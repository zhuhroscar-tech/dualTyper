DUALTYPER 0.1.0 — LOCAL TEST BUILD

DualTyper is a macOS Input Source that keeps your original sentence visible and adds an on-device Apple translation beneath it after sentence-ending punctuation or Return.

INSTALL
1. In Finder, hold Option and choose Go > Library.
2. Open the “Input Methods” folder. Create it if it does not exist.
3. Drag DualTyper.inputmethod from this DMG into that folder.
4. In System Settings, open Keyboard > Text Input > Edit.
5. Click + and add DualTyper under English.
6. Select DualTyper from the menu-bar Input menu.

USE
Type normally. Finish a sentence with . ! ? 。！？ or Return. The translated sentence is committed on the next line. Use the DualTyper Input menu to select a target language.

REQUIREMENTS
- macOS 15 or later.
- Apple translation language assets may need to download the first time a language pair is used.
- Standard Cocoa text fields are the MVP compatibility target.

PRIVACY
Translation uses Apple’s on-device Translation framework. DualTyper does not operate a server and does not intentionally persist sentence content.

BUILD STATUS
This DMG is ad-hoc signed for local testing because no Apple Developer ID certificate or notarization profile was available on the build machine. Gatekeeper-ready commercial distribution requires Developer ID signing and Apple notarization.

UNINSTALL
In Finder, open ~/Library/Input Methods and move DualTyper.inputmethod to the Trash. Log out and back in if it still appears in the Input menu.
