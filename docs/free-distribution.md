# Free distribution and installation

## What this route accomplishes

`DualTyper-0.3.0-FREE-UNNOTARIZED.dmg` is a normal universal macOS application that does not depend on InputMethodKit registration or Apple Developer Program membership. It runs from the menu bar and translates only text the user explicitly selects.

The artifact contains:

```text
DualTyper.app
Applications -> /Applications
```

The app is ad-hoc signed. This seals the bundle’s code and resources but does not establish a developer identity trusted by Gatekeeper.

## Why users must approve it

Apple documents a local exception for apps from unknown developers. The user first attempts to open DualTyper, then goes to **System Settings → Privacy & Security → Security → Open Anyway**. The exception applies to that app on that Mac.

DualTyper also needs separate Accessibility permission to read and replace the explicit selection. The user enables it under **System Settings → Privacy & Security → Accessibility**. If macOS does not list it automatically, the user can click **+** and choose `/Applications/DualTyper.app`.

Because this free build has no stable Developer ID identity, replacing the app with a rebuilt or updated ad-hoc binary can reset the Accessibility grant. If DualTyper shows permission as disabled after an update, remove its old Accessibility-list entry, add the exact new `/Applications/DualTyper.app`, and enable it again.

These steps are user-controlled and must never be bypassed by scripts, `xattr` removal instructions, SIP changes, TCC database modification, or administrator-policy workarounds.

## Compatibility promise

The strongest honest promise without paid signing is:

- runs on Intel and Apple-silicon Macs with macOS 15 or later;
- requires the owner or administrator to permit unknown-developer apps;
- requires the user to grant Accessibility;
- requires the setup window to remain open or minimized while its SwiftUI-owned Translation session is used;
- works only where the target app exposes a readable and settable Accessibility text selection;
- refuses macOS secure-input mode and controls exposed as `AXSecureTextField`;
- may be blocked entirely by organizational device management.

The app performs a best-effort stale-selection guard immediately before insertion. macOS Accessibility does not provide an atomic compare-and-set primitive across processes, so no Accessibility utility can promise that a target will not change in the final instant between validation and replacement.

It is not possible to guarantee operation on literally every Mac because the Mac owner or administrator can prohibit unnotarized code or Accessibility access. A product must respect that policy.

## End-user verification

A publisher should provide the DMG checksum over a separate trusted channel. Users can verify it with:

```bash
cd ~/Downloads
shasum -a 256 -c DualTyper-0.3.0-FREE-UNNOTARIZED.dmg.sha256
```

Verified v0.3.0 artifact after the final Translation-session recovery fix:

```text
SHA-256  9ab7355764459f9b9816428556acdd76080b0c21e730cfeb34d9ef113f112525
Bytes    471503
```

Rebuilding the DMG may change the checksum even when source code is unchanged.

## Maintainer verification

Run:

```bash
./scripts/package-menubar-dmg.sh
```

The script fails unless:

- the Swift test suite passes;
- the direct dependency-free tests pass;
- the Release executable contains exactly `arm64` and `x86_64`;
- the app’s ad-hoc code signature verifies structurally;
- the DMG image verifies;
- the visible root contains exactly the app and Applications link;
- the mounted app retains its signature and architectures;
- the checksum sidecar verifies;
- Gatekeeper rejects the build, confirming that it was not mislabeled as notarized.

## Paid path remains optional

Developer ID signing and Apple notarization would remove the unknown-developer approval step and provide stronger supply-chain identity. They are not required for this manual local-exception workflow, but there is no legitimate free replacement for the trust and convenience they provide.
