# Release packaging

DualTyper's supported public artifact is the shortcut-driven menu-bar app, not
the legacy InputMethodKit prototype. The `.inputmethod` target remains in the
repository for reference, but ad-hoc input-source registration is unreliable and
must not be presented as the current install path.

## Free menu-bar DMG

Build the tested universal local DMG with:

```bash
./scripts/package-menubar-dmg.sh
```

The output is `dist/DualTyper-<version>-FREE-UNNOTARIZED.dmg`. It contains:

```text
DualTyper.app
Applications -> /Applications
```

The app is ad-hoc signed and intentionally unnotarized, so users must approve the
unknown-developer app locally and grant Accessibility permission themselves. The
packager verifies the Swift test suite, direct core tests, universal
architectures, structural code signature, DMG payload, checksum sidecar, and
Gatekeeper rejection. See `docs/free-distribution.md` for the exact user-facing
verification and permission language.

## Legacy input-method prototype

`scripts/package-dmg.sh` builds the old `DualTyper.inputmethod` development
artifact. It is useful only for local experiments with InputMethodKit and manual
copying to `~/Library/Input Methods`; it is not the downloadable release product
and should not be linked from end-user installation instructions.

## Developer ID distribution

A notarized commercial-grade menu-bar release should:

1. Build `DualTyper.app` in Release for arm64 and x86_64.
2. Sign the app with a Developer ID Application identity and hardened runtime.
3. Validate the signature with `codesign --verify --deep --strict --verbose=2`.
4. Put the signed app and Applications symlink in a DMG.
5. Sign the DMG, submit it with `notarytool`, staple the ticket, then validate
   with `spctl` on a clean macOS 15+ user account.
6. Publish a checksum and retain symbols for each release.

Apple Translation language-model prompts and downloads remain system-owned and
must not be automated. Notarization credentials must already exist in the
builder's Keychain via `xcrun notarytool store-credentials`. Never commit
certificate exports, Keychain passwords, app-specific passwords, or App Store
Connect keys.
