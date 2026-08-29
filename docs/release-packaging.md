# Release packaging

The `.inputmethod` bundle is the installable engine. A DMG is only a transport;
macOS does not activate an input source merely because the DMG was opened.

## Development DMG

Place `DualTyper.inputmethod` in a read-only DMG beside an `Install DualTyper`
launcher or instructions. A manual install copies the bundle to
`~/Library/Input Methods`, then the user logs out/in and adds DualTyper in
**System Settings → Keyboard → Text Input → Edit**.

## Commercial distribution

Do not ship the current unsigned local artifact. A release pipeline should:

1. Build `DualTyper.inputmethod` in Release for arm64 and x86_64.
2. Sign the nested executable and bundle with a Developer ID Application
   identity, hardened runtime, and the final reverse-DNS bundle identifier.
3. Validate the signature with `codesign --verify --deep --strict --verbose=2`.
4. Put the signed input method and a signed installer/uninstaller app in a DMG.
   The installer should copy only after explicit user action, replace old
   versions safely, and explain the required logout/input-source steps.
5. Sign the DMG, submit it with `notarytool`, staple the ticket, then validate
   with `spctl` on a clean Mac.
6. Publish a checksum and retain symbols for each release.

A polished installer should also detect an existing version, avoid modifying
System Settings automatically, provide uninstall, and link to privacy/support
material. Apple Translation language-model prompts and downloads remain
system-owned and must not be automated.

The current target intentionally disables signing for reproducible local builds.
Before release, supply `DEVELOPMENT_TEAM`, enable signing/hardened runtime, and
review sandbox/temporary Mach registration requirements against the then-current
InputMethodKit documentation. Notarization and first-run validation on a clean
macOS 15+ user account are release blockers.
