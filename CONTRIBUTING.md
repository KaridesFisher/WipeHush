# Contributing

Small, focused fixes and improvements are welcome.

1. Fork the repository and create a branch for your change.
2. Keep all application text, documentation, comments, and issue templates in English.
3. Run `bash scripts/test.sh` and `bash scripts/build.sh` on macOS.
4. For input or window changes, complete the relevant checks in `docs/TESTING.md`.
5. Open a pull request describing the problem, the resulting behavior, and what you tested.

Keep the app dependency-free and avoid background services, input logging, or network requests. Do not extend session length beyond two minutes without discussing the recovery implications first. Preserve a reliable exit path and cleanup of event taps.

For bugs, include the app version, macOS version, Mac model/chip, reproduction steps, and whether the Esc progress and automatic timeout worked. Do not include passwords or unrelated personal information.

## Releases

Update both version fields in `Resources/Info.plist` and the About panel, document the change in `CHANGELOG.md`, then push a version tag such as `v1.2.0`. The tagged-release workflow tests and builds the app and publishes the ZIP and SHA-256 checksum. Release binaries are ad-hoc signed, not Apple-notarized.
