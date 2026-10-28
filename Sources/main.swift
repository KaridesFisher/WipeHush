import AppKit
import ApplicationServices

private let accent = NSColor(calibratedRed: 0.54, green: 0.94, blue: 0.76, alpha: 1)
private let muted = NSColor(calibratedWhite: 0.62, alpha: 1)

func text(_ value: String, size: CGFloat = 14, weight: NSFont.Weight = .regular, color: NSColor = .white) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: value)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    return field
}

final class Card: NSView {
    init(color: NSColor = NSColor(calibratedWhite: 0.105, alpha: 1)) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class CoverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var permissionLabel: NSTextField!
    private var permissionButton: NSButton!
    private var startButton: NSButton!
    private var durationControl: NSSegmentedControl!
    private var permissionTimer: Timer?
    private var sessionTimer: Timer?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var covers: [NSWindow] = []
    private var hints: [NSTextField] = []
    private var session = CleaningSession()
    private var activity: NSObjectProtocol?
    private var isTerminating = false
    private let durations: [TimeInterval] = [30, 60, 120]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildMenu()
        buildWindow()
        refreshPermission()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refreshPermission() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(interrupted), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(interrupted), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMenu() {
        let menu = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About WipeHush", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit WipeHush", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu
        menu.addItem(root)
        NSApp.mainMenu = menu
    }

    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "WipeHush",
            .applicationVersion: "1.3.0",
            .version: "4",
            .credits: NSAttributedString(string: "A little pause for a cleaner workspace.\nFree and open source under the MIT License.\nCreated by KaridesFisher.")
        ])
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 660), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "WipeHush"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedWhite: 0.065, alpha: 1)
        window.isReleasedWhenClosed = false
        guard let content = window.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
        ])

        let brand = NSStackView()
        brand.orientation = .horizontal
        brand.spacing = 12
        let symbol = NSImageView(image: NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "WipeHush") ?? NSImage())
        symbol.contentTintColor = accent
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 25, weight: .medium)
        symbol.widthAnchor.constraint(equalToConstant: 38).isActive = true
        symbol.heightAnchor.constraint(equalToConstant: 38).isActive = true
        brand.addArrangedSubview(symbol)
        brand.addArrangedSubview(text("WIPEHUSH", size: 12, weight: .bold, color: accent))
        stack.addArrangedSubview(brand)
        stack.addArrangedSubview(text("A little pause.\nA cleaner workspace.", size: 33, weight: .bold))
        stack.addArrangedSubview(text("Block accidental keystrokes and trackpad input while you wipe. A black screen makes smudges easier to spot.", size: 15, color: muted))

        let card = Card()
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let settings = NSStackView()
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 16
        settings.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(settings)
        NSLayoutConstraint.activate([
            settings.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            settings.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            settings.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            settings.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        let permissionRow = NSStackView()
        permissionRow.orientation = .horizontal
        permissionRow.distribution = .fill
        permissionLabel = text("Checking permission...", size: 13, weight: .medium)
        permissionButton = NSButton(title: "Open Settings", target: self, action: #selector(openPermissions))
        permissionButton.bezelStyle = .rounded
        permissionRow.addArrangedSubview(permissionLabel)
        permissionRow.addArrangedSubview(NSView())
        permissionRow.addArrangedSubview(permissionButton)
        settings.addArrangedSubview(permissionRow)
        permissionRow.widthAnchor.constraint(equalTo: settings.widthAnchor).isActive = true
        let line = NSBox(); line.boxType = .separator
        settings.addArrangedSubview(line)
        line.widthAnchor.constraint(equalTo: settings.widthAnchor).isActive = true
        let durationRow = NSStackView()
        durationRow.orientation = .horizontal
        durationRow.addArrangedSubview(text("Auto-unlock after", size: 14))
        durationRow.addArrangedSubview(NSView())
        durationControl = NSSegmentedControl(labels: ["30 sec", "1 min", "2 min"], trackingMode: .selectOne, target: nil, action: nil)
        durationControl.selectedSegment = 2
        durationRow.addArrangedSubview(durationControl)
        settings.addArrangedSubview(durationRow)
        durationRow.widthAnchor.constraint(equalTo: settings.widthAnchor).isActive = true
        settings.addArrangedSubview(text("Hold Esc for 2 seconds to unlock at any time.", size: 12, color: muted))

        startButton = NSButton(title: "Start Cleaning", target: self, action: #selector(startCleaning))
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.font = .systemFont(ofSize: 16, weight: .semibold)
        startButton.bezelColor = accent
        startButton.contentTintColor = .black
        stack.addArrangedSubview(startButton)
        startButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        startButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(text("Use a dry microfiber cloth. Your computer stays on. Power / Touch ID is not blocked; avoid holding it down.", size: 12, color: muted))
        let footer = text("FREE & OPEN SOURCE  /  NO ACCOUNT  /  NO TRACKING", size: 10, weight: .medium, color: NSColor(white: 0.42, alpha: 1))
        stack.addArrangedSubview(footer)
        footer.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20).isActive = true
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        permissionLabel.stringValue = trusted ? "Accessibility access is ready" : "Accessibility access is required"
        permissionLabel.textColor = trusted ? accent : NSColor.systemOrange
        permissionButton.title = trusted ? "Settings" : "Grant Access"
        startButton.isEnabled = trusted
    }

    @objc private func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func startCleaning() {
        guard !session.isActive else { return }
        guard AXIsProcessTrusted() else { refreshPermission(); return }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel, CGEventType(rawValue: 14)!]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, data in
            guard let data = data else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async { app.stopCleaning() }
                return Unmanaged.passUnretained(event)
            }
            if (type == .keyDown || type == .keyUp), event.getIntegerValueField(.keyboardEventKeycode) == 53 {
                app.session.escapeKey(isDown: type == .keyDown, now: ProcessInfo.processInfo.systemUptime)
            }
            return app.session.isActive ? nil : Unmanaged.passUnretained(event)
        }, userInfo: context) else {
            showError("Could not block input", detail: "Enable WipeHush in System Settings > Privacy & Security > Accessibility, then quit and reopen the app. After updating the app, you may need to remove its old permission entry and add it again.")
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            showError("Could not start cleaning", detail: "The input event source could not be created. Please quit and reopen WipeHush.")
            return
        }
        tap = newTap
        source = newSource
        let selected = durationControl.selectedSegment
        session.start(duration: durations.indices.contains(selected) ? durations[selected] : 120, now: ProcessInfo.processInfo.systemUptime)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled], reason: "Cleaning session")
        window.orderOut(nil)
        showCovers()
        tick()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        sessionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func showCovers() {
        for screen in NSScreen.screens {
            let cover = CoverWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            cover.backgroundColor = .black
            cover.isOpaque = true
            cover.level = .screenSaver
            cover.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            cover.hidesOnDeactivate = false
            cover.isReleasedWhenClosed = false
            let hint = text("", size: 13, weight: .medium, color: NSColor(white: 0.35, alpha: 1))
            hint.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            hint.alignment = .center
            hint.translatesAutoresizingMaskIntoConstraints = false
            cover.contentView!.addSubview(hint)
            NSLayoutConstraint.activate([
                hint.centerXAnchor.constraint(equalTo: cover.contentView!.centerXAnchor),
                hint.leadingAnchor.constraint(greaterThanOrEqualTo: cover.contentView!.leadingAnchor, constant: 20),
                hint.trailingAnchor.constraint(lessThanOrEqualTo: cover.contentView!.trailingAnchor, constant: -20),
                hint.bottomAnchor.constraint(equalTo: cover.contentView!.bottomAnchor, constant: -32)
            ])
            hints.append(hint)
            covers.append(cover)
            cover.orderFrontRegardless()
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if session.shouldStop(now: now) { stopCleaning(); return }
        let seconds = session.remainingSeconds(now: now)
        let progress = session.escapeProgress(now: now)
        let message = progress > 0
            ? "UNLOCKING  \(Int(progress * 100))%  /  Keep holding Esc"
            : "CLEANING MODE  /  Hold Esc for 2 sec to unlock  /  \(seconds)s remaining"
        hints.forEach { $0.stringValue = message }
    }

    @objc private func interrupted() { if session.isActive { stopCleaning() } }

    private func stopCleaning() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        session.stop()
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        covers.forEach { $0.close() }
        covers.removeAll()
        hints.removeAll()
        if let activity = activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        if !isTerminating {
            refreshPermission()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !session.isActive { window.makeKeyAndOrderFront(nil) }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        permissionTimer?.invalidate()
        stopCleaning()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !session.isActive && covers.isEmpty }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
