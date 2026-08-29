# Release packaging

The `.inputmethod` bundle is the installable engine. A DMG is only a transport;
macOS does not activate an input source merely because the DMG was opened.

## Development DMG

Build the tested universal local DMG with:

```bash
./scripts/package-dmg.sh
```

The output is `dist/DualTyper-0.1.0.dmg`. It contains the input method and
manual Finder installation instructions. The user copies the bundle to
`~/Library/Input Methods`, then adds DualTyper in **System Settings → Keyboard
→ Text Input → Edit**. The local-test DMG intentionally contains no executable
installer or uninstaller scripts.

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

`scripts/package-dmg.sh` intentionally rejects `SIGN_IDENTITY` and
`NOTARY_PROFILE`; it is a local-test packager, not a commercial release path.
The commercial pipeline must add a signed installer/uninstaller app or signed
installer package. Its
notarization credentials must already exist in the builder's Keychain via
`xcrun notarytool store-credentials`. Never commit certificate exports,
Keychain passwords, app-specific passwords, or App Store Connect keys.
