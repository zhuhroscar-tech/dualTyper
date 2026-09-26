# Changelog

All notable DualTyper source and distribution changes are tracked here.

## 0.3.4 — 2026-09-26

- Corrected stale release-packaging documentation that still described the legacy InputMethodKit `.inputmethod` artifact as the installable engine.
- Added repository-contract coverage so packaging docs keep pointing users to the supported menu-bar DMG and keep the input-method prototype clearly marked as non-release-only.

This is a source-quality release. The current downloadable DMG remains `v0.3.0` until the next packaged build.

## 0.3.3 — 2026-09-25

- Made Core CI's release-tag coverage explicit so source-release tags continue running the same Swift, core, and repository-contract checks as main.
- Added repository-contract coverage for the tag-triggered CI contract.

This is a source-quality release. The current downloadable DMG remains `v0.3.0` until the next packaged build.

## 0.3.2 — 2026-09-24

- Added a maintained changelog so users can distinguish source-quality maintenance releases from the current downloadable app build.
- Added repository-contract coverage that keeps the changelog linked from the README and aligned with published source releases.

This is a source-quality release. The current downloadable DMG remains `v0.3.0` until the next packaged build.

## 0.3.1 — 2026-09-23

- Added repository-contract tests for required project files, README local links/assets, public artifact identity docs, CI test coverage, and XcodeGen target declarations.
- Wired the contract tests into Core CI.

This was a source-quality release; the downloadable app remained `v0.3.0`.

## 0.3.0 — 2026-08-30

- Published the first free, ad-hoc signed, unnotarized menu-bar DMG build.
- Verified universal `arm64` + `x86_64` executable structure, package signature layout, checksum, byte count, strict Release build, and 33 core tests.
- Documented Accessibility, unknown-developer approval, and managed-Mac limitations.

## 0.1.0 — 2026-08-29

- Published the local test build baseline.
