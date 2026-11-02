import Cocoa
import ServiceManagement

final class OverviewPanel: NSPanel { override var canBecomeKey: Bool { true } }
final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var panel: NSPanel!
    var selector: NSPopUpButton!
    var content: NSTextView!
    var notice: NSTextField!
    var watcher: DispatchSourceFileSystemObject?
    var retry: Timer?
    var ageTimer: Timer?
    var ids: [String] = []
    var cached: [String: [String: Any]] = [:]
    var hasValidSnapshot = false
    let root: URL = {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--store"), index + 1 < args.count { return URL(fileURLWithPath: args[index + 1], isDirectory: true) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ProjectOverview", isDirectory: true)
    }()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem); let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Project Overview", action: #selector(quit), keyEquivalent: "q"); appItem.submenu = appMenu; NSApp.mainMenu = main
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength); status.button?.title = "Glance"; status.button?.setAccessibilityLabel("Glance project overview")
        let menu = NSMenu(); menu.autoenablesItems = false; menu.addItem(withTitle: "Show / Hide", action: #selector(toggle), keyEquivalent: ""); menu.addItem(withTitle: "Open project context", action: #selector(openContext), keyEquivalent: ""); let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: ""); login.state = SMAppService.mainApp.status == .enabled ? .on : .off; let location = menu.addItem(withTitle: "Store: \(root.path)", action: nil, keyEquivalent: ""); location.isEnabled = false; menu.addItem(.separator()); menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q"); status.menu = menu
        panel = OverviewPanel(contentRect: NSRect(x: 160, y: 160, width: 380, height: 400), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Project overview"; panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
        panel.setFrameAutosaveName("ProjectOverviewPanel"); clampToScreen()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        selector = NSPopUpButton(); selector.target = self; selector.action = #selector(selectProject); stack.addArrangedSubview(selector)
        notice = NSTextField(wrappingLabelWithString: ""); notice.textColor = .systemOrange; stack.addArrangedSubview(notice)
        let scroll = NSTextView.scrollableTextView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        content = scroll.documentView as? NSTextView; content.isEditable = false; content.isSelectable = true; content.drawsBackground = false; content.font = NSFont.systemFont(ofSize: 13); content.string = "Status unknown."
        stack.addArrangedSubview(scroll); panel.contentView = stack
        selector.widthAnchor.constraint(equalToConstant: 344).isActive = true; notice.widthAnchor.constraint(equalToConstant: 344).isActive = true; scroll.widthAnchor.constraint(equalToConstant: 344).isActive = true; scroll.heightAnchor.constraint(equalToConstant: 290).isActive = true
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        refresh(); watch()
        ageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        panel.orderFrontRegardless()
    }
    func clampToScreen() { guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) }) ?? NSScreen.main else { return }; var f = panel.frame; let v = screen.visibleFrame; f.origin.x = min(max(f.origin.x, v.minX), max(v.minX, v.maxX-f.width)); f.origin.y = min(max(f.origin.y, v.minY), max(v.minY, v.maxY-f.height)); panel.setFrame(f, display: false) }
    @objc func toggle() { if panel.isVisible { panel.orderOut(nil) } else { clampToScreen(); panel.orderFrontRegardless() } }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func openContext() {
        guard let id = selector.selectedItem?.representedObject as? String, let data = cached[id]?["status"] as? [String: Any], let raw = data["contextURL"] as? String, let url = URL(string: raw), let scheme = url.scheme?.lowercased(), ["file", "http", "https", "codex"].contains(scheme) else { let alert = NSAlert(); alert.messageText = "No supported context link"; alert.informativeText = "This project has no valid context URL."; alert.runModal(); return }
        if scheme == "file" { NSWorkspace.shared.activateFileViewerSelecting([url]) } else { NSWorkspace.shared.open(url) }
    }
    @objc func toggleLogin(_ sender: NSMenuItem) {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } }
        catch { let alert = NSAlert(); alert.messageText = "Could not change Open at Login"; alert.informativeText = error.localizedDescription; alert.runModal() }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if SMAppService.mainApp.status == .requiresApproval { let alert = NSAlert(); alert.messageText = "Login item needs approval"; alert.informativeText = "macOS requires approval in Login Items settings."; alert.runModal() }
    }
    @objc func wake() { refresh(); watch() }
    @objc func screenChanged() { clampToScreen() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { clampToScreen(); panel.orderFrontRegardless(); return true }
    @objc func selectProject() { if let id = selector.selectedItem?.representedObject as? String { UserDefaults.standard.set(id, forKey: "selectedProject") }; display() }
    func object(_ url: URL) -> [String: Any]? { guard let data = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }; return obj }
    func refresh() {
        let url = root.appendingPathComponent("store.json")
        guard FileManager.default.fileExists(atPath: url.path) else { if hasValidSnapshot { notice.stringValue = "Unavailable: showing the last saved view." } else { notice.stringValue = "No saved project data found."; content.string = "Status unknown." }; return }
        guard let store = object(url), store["schema"] as? Int == 1, let projects = store["projects"] as? [String: [String: Any]], projects.allSatisfy({ key, record in key.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil && record["id"] as? String == key && record["status"] is [String: Any] }) else { notice.stringValue = hasValidSnapshot ? "Unavailable: showing the last saved view." : "Saved project data is unavailable or invalid."; if !hasValidSnapshot { content.string = "Status unknown." }; return }
        cached = projects; hasValidSnapshot = true; notice.stringValue = ""; ids = projects.keys.sorted(); selector.removeAllItems()
        for id in ids { let name = (projects[id]?["status"] as? [String: Any])?["name"] as? String ?? id; let item = NSMenuItem(title: "\(name) · \(id)", action: nil, keyEquivalent: ""); item.representedObject = id; selector.menu?.addItem(item) }
        if let selected = UserDefaults.standard.string(forKey: "selectedProject"), let item = selector.itemArray.first(where: { $0.representedObject as? String == selected }) { selector.select(item) }
        display()
    }
    func display() {
        guard let id = selector.selectedItem?.representedObject as? String else { content.string = "No projects enrolled."; return }
        guard let record = cached[id], let data = record["status"] as? [String: Any], let goal = data["goal"] as? String, let checkpoint = data["checkpoint"] as? String, let state = data["status"] as? String, let updated = record["updatedAt"] as? String else { content.string = "Project record is invalid. Its status is unknown."; return }
        let date = ISO8601DateFormatter().date(from: updated)
        let freshness = date.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) } ?? "unknown"
        let stale = date.map { Date().timeIntervalSince($0) > 7 * 86400 } ?? true
        let formatted = NSMutableAttributedString()
        func add(_ title: String, _ value: String) {
            formatted.append(NSAttributedString(string: title + "\n", attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]))
            formatted.append(NSAttributedString(string: value + "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor]))
        }
        let name = data["name"] as? String ?? id
        add("PROJECT", "\(name) · \(id)"); add("STATUS", state); add("CHECKPOINT", checkpoint)
        add("NEXT / BLOCKER", (data["next"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Not provided")
        add("REMAINING EFFORT", (data["effort"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown")
        add("GOAL", goal)
        for (key, title) in [("milestones", "MILESTONES"), ("sources", "SOURCES")] { if let value = data[key] as? String, !value.isEmpty { add(title, value) } }
        formatted.append(NSAttributedString(string: "\(stale ? "STALE · " : "")Updated \(freshness) · \(updated)", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
        content.textStorage?.setAttributedString(formatted)
    }
    func watch() {
        watcher?.cancel(); watcher = nil
        let fd = open(root.path, O_EVTONLY)
        guard fd >= 0 else { scheduleRetry(); return }
        retry?.invalidate(); retry = nil
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self, weak source] in guard let self, let source else { return }; self.refresh(); if !source.data.intersection([.rename, .delete]).isEmpty { self.watch() } }
        source.setCancelHandler { close(fd) }; source.resume(); watcher = source
    }
    func scheduleRetry() { guard retry == nil else { return }; retry = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.watch(); self?.refresh() } }
}
let app = NSApplication.shared
let delegate = AppDelegate(); app.delegate = delegate; app.run()
