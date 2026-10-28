# Manual verification

Automated tests exercise session logic without taking control of the tester's input. They do not prove that an operating system grants permissions or delivers physical keyboard events.

Use a dry cloth. Save unrelated work before testing input interception.

- Launch without Accessibility access: status is explanatory and Start Cleaning is disabled.
- Click Grant Access, enable the app, and return: permission status updates and Start Cleaning becomes enabled.
- Start a 30-second session: connected displays receive black covers and the remaining time appears.
- Press ordinary keys, click, scroll, and move the pointer: verify no input reaches another app.
- Hold Esc for one second, then release: progress resets and the session continues.
- Hold Esc for two continuous seconds: progress reaches completion, the covers close, and normal input resumes.
- Let each session duration expire without input: verify automatic release.
- Repeat several sessions: no covers or input taps remain after exit.
- Verify behavior with an external keyboard/mouse and multiple displays.
- Sleep or reconfigure displays during a session: the session ends.
- Update/rebuild the app: document whether Accessibility access needs re-granting.
- Verify launch and physical input handling on Apple Silicon and Intel hardware.

Do not test forced power-off as part of this checklist. The Power / Touch ID button is outside the app's control.
