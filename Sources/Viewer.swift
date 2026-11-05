import Cocoa
import ServiceManagement
import CoreFoundation

struct Milestone { let id: String; let title: String; let done: Bool }
enum Checklist { case items([Milestone]), missing, invalid }
func checklist(_ data: [String: Any]) -> Checklist {
    guard let raw = data["checklist"] else { return .missing }
    guard let list = raw as? [[String: Any]] else { return .invalid }
    var ids = Set<String>(), output: [Milestone] = []
    for item in list {
        guard let id = item["id"] as? String, id.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil, ids.insert(id).inserted,
              let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let value = item["done"] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return .invalid }
        output.append(Milestone(id: id, title: title, done: value.boolValue))
    }
    return .items(output)
}
let shell = NSColor(calibratedWhite: 0.085, alpha: 1)
let inset = NSColor(calibratedWhite: 0.14, alpha: 1)
let muted = NSColor(calibratedWhite: 0.66, alpha: 1)
func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .white) -> NSTextField {
    let v = NSTextField(wrappingLabelWithString: text); v.font = .systemFont(ofSize: size, weight: weight); v.textColor = color; v.maximumNumberOfLines = 0; v.setContentCompressionResistancePriority(.required, for: .vertical); return v
}
func column(_ spacing: CGFloat = 8) -> NSStackView { let s = NSStackView(); s.orientation = .vertical; s.alignment = .leading; s.spacing = spacing; return s }
func card() -> NSStackView { let s = column(8); s.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12); s.wantsLayer = true; s.layer?.backgroundColor = inset.cgColor; s.layer?.cornerRadius = 10; s.layer?.borderColor = NSColor(white: 1, alpha: 0.1).cgColor; s.layer?.borderWidth = 1; return s }
func addFull(_ child: NSView, to stack: NSStackView) { stack.addArrangedSubview(child); child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -(stack.edgeInsets.left + stack.edgeInsets.right)).isActive = true }

final class TopClipView: NSClipView { override var isFlipped: Bool { true } }
final class Overview: NSView {
    let picker = NSPopUpButton(); let body = column(10); let scroll = NSScrollView(); let notice = label("", size: 11, color: .systemOrange)
    var onSelect: ((String) -> Void)?; var onSettings: (() -> Void)?; var onQuit: (() -> Void)?; var onContext: (() -> Void)?
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 510)); wantsLayer = true; layer?.backgroundColor = shell.cgColor
        appearance = NSAppearance(named: .darkAqua)
        let title = NSStackView(); title.orientation = .horizontal; title.alignment = .centerY; title.spacing = 8
        let mark = NSImageView(); mark.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil); mark.contentTintColor = .white; mark.widthAnchor.constraint(equalToConstant: 20).isActive = true; mark.heightAnchor.constraint(equalToConstant: 20).isActive = true; title.addArrangedSubview(mark); title.addArrangedSubview(label("Glance", size: 17, weight: .semibold))
        picker.target = self; picker.action = #selector(selection); picker.controlSize = .large
        scroll.contentView = TopClipView(); scroll.contentView.clipsToBounds = true; scroll.clipsToBounds = true; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.borderType = .noBorder
        body.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = body
        NSLayoutConstraint.activate([body.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), body.topAnchor.constraint(equalTo: scroll.contentView.topAnchor), body.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)])
        let footer = NSStackView(); footer.orientation = .horizontal; footer.distribution = .fillEqually; footer.spacing = 8
        let settingsButton = NSButton(title: "Settings", target: self, action: #selector(settingsClicked)); settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil); settingsButton.imagePosition = .imageLeading
        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitClicked)); quitButton.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil); quitButton.imagePosition = .imageLeading; footer.addArrangedSubview(settingsButton); footer.addArrangedSubview(quitButton)
        for v in [title, picker, notice, scroll, footer] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 16), title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16), title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            picker.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12), picker.leadingAnchor.constraint(equalTo: title.leadingAnchor), picker.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            notice.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 2), notice.leadingAnchor.constraint(equalTo: title.leadingAnchor), notice.trailingAnchor.constraint(equalTo: title.trailingAnchor), notice.heightAnchor.constraint(equalToConstant: 15),
            scroll.topAnchor.constraint(equalTo: notice.bottomAnchor, constant: 4), scroll.leadingAnchor.constraint(equalTo: title.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: title.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            footer.leadingAnchor.constraint(equalTo: title.leadingAnchor), footer.trailingAnchor.constraint(equalTo: title.trailingAnchor), footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16), footer.heightAnchor.constraint(equalToConstant: 27)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func selection() { if let id = picker.selectedItem?.representedObject as? String { onSelect?(id) } }
    @objc func settingsClicked() { onSettings?() }
    @objc func quitClicked() { onQuit?() }
    @objc func contextClicked() { onContext?() }
    func render(projects: [String: [String: Any]], selected: String?, unavailable: Bool) {
        let ids = projects.keys.sorted(); picker.removeAllItems()
        for id in ids { let data = projects[id]?["status"] as? [String: Any]; let name = data?["name"] as? String ?? id; let item = NSMenuItem(title: "\(name) · \(id)", action: nil, keyEquivalent: ""); item.representedObject = id; picker.menu?.addItem(item) }
        if let selected, let item = picker.itemArray.first(where: { $0.representedObject as? String == selected }) { picker.select(item) }
        notice.stringValue = unavailable ? (projects.isEmpty ? "Saved data unavailable" : "Unavailable · showing last saved view") : ""
        body.arrangedSubviews.forEach { body.removeArrangedSubview($0); $0.removeFromSuperview() }
        guard let id = picker.selectedItem?.representedObject as? String, let record = projects[id] else { addFull(label(unavailable ? "Project status is unavailable." : "No projects enrolled.", color: muted), to: body); return }
        guard let data = record["status"] as? [String: Any], let goal = data["goal"] as? String, let checkpoint = data["checkpoint"] as? String, let status = data["status"] as? String else { addFull(label("Project status is invalid or unavailable.", color: .systemOrange), to: body); return }
        let overview = card(); addFull(label("PROJECT OVERVIEW", size: 10, weight: .bold, color: muted), to: overview); addFull(label(status, size: 14, weight: .semibold), to: overview); addFull(label("Checkpoint  ·  " + checkpoint), to: overview); addFull(label("Goal  ·  " + goal, color: muted), to: overview); addFull(overview, to: body)
        let milestones = card(); addFull(label("MILESTONES", size: 10, weight: .bold, color: muted), to: milestones)
        switch checklist(data) {
        case .missing: addFull(label("No milestones recorded", color: muted), to: milestones)
        case .invalid: addFull(label("Milestones unavailable · invalid data", color: .systemOrange), to: milestones)
        case .items(let items):
            if items.isEmpty { addFull(label("No milestones recorded", color: muted), to: milestones) }
            for item in items {
                let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.spacing = 8
                let symbol = NSImageView(); symbol.image = NSImage(systemSymbolName: item.done ? "checkmark.square.fill" : "square", accessibilityDescription: nil); symbol.contentTintColor = item.done ? .systemBlue : muted; symbol.widthAnchor.constraint(equalToConstant: 16).isActive = true; symbol.heightAnchor.constraint(equalToConstant: 17).isActive = true
                let title = label(item.title, color: item.done ? .white : NSColor(white: 0.8, alpha: 1)); row.addArrangedSubview(symbol); row.addArrangedSubview(title); title.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -24).isActive = true
                row.setAccessibilityElement(true); row.setAccessibilityRole(.checkBox); row.setAccessibilityLabel(item.title + ", read only"); row.setAccessibilityValue(item.done ? 1 : 0); addFull(row, to: milestones)
            }
        }
        addFull(milestones, to: body)
        let next = card(); addFull(label("NEXT", size: 10, weight: .bold, color: muted), to: next); addFull(label((data["next"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Not provided"), to: next)
        if let effort = data["effort"] as? String, !effort.isEmpty { addFull(label("Effort  ·  " + effort, color: muted), to: next) }
        if data["contextURL"] is String { let button = NSButton(title: "Open project context", target: self, action: #selector(contextClicked)); addFull(button, to: next) }
        addFull(next, to: body)
        let updated = record["updatedAt"] as? String ?? ""; let date = ISO8601DateFormatter().date(from: updated); let age = date.map { d -> String in let seconds = Date().timeIntervalSince(d); if seconds < -60 { return "clock mismatch · future timestamp" }; if seconds < 60 { return "just now" }; return RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()) } ?? "unknown"; let stale = date.map { Date().timeIntervalSince($0) > 7*86400 } ?? true
        addFull(label("\(stale ? "STALE  ·  " : "")Updated \(age)", size: 11, color: muted), to: body)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let root: URL = { let args = CommandLine.arguments; if let i = args.firstIndex(of: "--store"), i+1 < args.count { return URL(fileURLWithPath: args[i+1], isDirectory: true) }; return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ProjectOverview", isDirectory: true) }()
    let overview = Overview(); let popover = NSPopover(); var status: NSStatusItem!; var watcher: DispatchSourceFileSystemObject?; var timer: Timer?; var retry: Timer?
    var cached: [String: [String: Any]] = [:]; var hasSnapshot = false; var selected = UserDefaults.standard.string(forKey: "selectedProject"); var unavailable = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory); let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item); let sub = NSMenu(); sub.addItem(withTitle: "Quit Glance", action: #selector(quit), keyEquivalent: "q"); item.submenu = sub; NSApp.mainMenu = menu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength); status.button?.title = "Glance"; status.button?.target = self; status.button?.action = #selector(toggle)
        let controller = NSViewController(); controller.view = overview; popover.contentViewController = controller; popover.contentSize = overview.frame.size; popover.behavior = .transient; popover.delegate = self
        overview.onSelect = { [weak self] id in self?.selected = id; UserDefaults.standard.set(id, forKey: "selectedProject"); self?.redraw() }; overview.onQuit = { NSApp.terminate(nil) }; overview.onSettings = { [weak self] in self?.settings() }; overview.onContext = { [weak self] in self?.openContext() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        refresh(); watch(); timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }; if CommandLine.arguments.contains("--show") { DispatchQueue.main.async { [weak self] in self?.showPopover() } }
    }
    @objc func toggle() { if popover.isShown { popover.performClose(nil) } else { showPopover() } }
    func showPopover(attempt: Int = 0) {
        guard !popover.isShown else { return }
        if let button = status.button, button.window != nil { refresh(); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        if !popover.isShown && attempt < 30 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.showPopover(attempt: attempt + 1) } }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPopover(); return true }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func wake() { refresh(); watch() }
    func redraw() { overview.render(projects: cached, selected: selected, unavailable: unavailable) }
    func refresh() {
        let url = root.appendingPathComponent("store.json")
        guard let data = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], obj["schema"] as? Int == 1, let projects = obj["projects"] as? [String: [String: Any]], projects.allSatisfy({ key, record in key.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil && record["id"] as? String == key && record["status"] is [String: Any] }) else { unavailable = true; redraw(); return }
        cached = projects; hasSnapshot = true; unavailable = false; redraw()
    }
    func watch() {
        watcher?.cancel(); watcher = nil; let fd = open(root.path, O_EVTONLY); guard fd >= 0 else { if retry == nil { retry = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.watch(); self?.refresh() } }; return }
        retry?.invalidate(); retry = nil; let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main); source.setEventHandler { [weak self, weak source] in guard let self, let source else { return }; self.refresh(); if !source.data.intersection([.rename, .delete]).isEmpty { self.watch() } }; source.setCancelHandler { close(fd) }; source.resume(); watcher = source
    }
    func openContext() {
        guard let id = overview.picker.selectedItem?.representedObject as? String, let data = cached[id]?["status"] as? [String: Any], let raw = data["contextURL"] as? String, let url = URL(string: raw), let scheme = url.scheme?.lowercased(), ["file", "http", "https", "codex"].contains(scheme) else { let alert = NSAlert(); alert.messageText = "No supported context link"; alert.runModal(); return }
        if scheme == "file" { NSWorkspace.shared.activateFileViewerSelecting([url]) } else { NSWorkspace.shared.open(url) }
    }
    func settings() {
        let alert = NSAlert(); alert.messageText = "Glance settings"; alert.informativeText = "Store: \(root.path)\nVersion: pilot"; alert.addButton(withTitle: "Done"); alert.addButton(withTitle: "Reveal Store"); alert.addButton(withTitle: SMAppService.mainApp.status == .enabled ? "Turn Off Open at Login" : "Turn On Open at Login")
        let result = alert.runModal(); if result == .alertSecondButtonReturn { NSWorkspace.shared.activateFileViewerSelecting([root]) }; if result == .alertThirdButtonReturn { do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } } catch { let failure = NSAlert(error: error); failure.runModal() } }
    }
}

func preview(_ path: String) {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let payload: [String: Any] = ["name":"Atlas", "goal":"Bring the project to a clear release checkpoint.", "checkpoint":"Finish the shared review", "status":"On track", "next":"Resolve the final review decision", "effort":"About 2–3 hours", "checklist": [["id":"scope", "title":"Agree the project scope", "done":true], ["id":"build", "title":"Build the first working version", "done":true], ["id":"verify", "title":"Verify the core workflow", "done":true], ["id":"docs", "title":"Record the project decisions", "done":true], ["id":"review", "title":"Complete the independent review", "done":false], ["id":"integrate", "title":"Connect the participating sessions", "done":false], ["id":"release", "title":"Finish the release checks", "done":false]]]
    let now = ISO8601DateFormatter().string(from: Date())
    let rec: [String: Any] = ["id":"demo", "status":payload, "updatedAt":now]
    func capture(_ name: String, _ projects: [String: [String: Any]], _ selected: String?, _ unavailable: Bool = false, bottom: Bool = false) {
        let view = Overview(); let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false); window.title = "Glance fictional demo · visual self-test"; window.contentView = view
        view.render(projects: projects, selected: selected, unavailable: unavailable); view.layoutSubtreeIfNeeded()
        if bottom { let distance = view.body.frame.height - view.scroll.contentSize.height; guard distance > 0 else { fputs("Long fixture did not create scrollable content\n", stderr); exit(2) }; view.scroll.contentView.scroll(to: NSPoint(x: 0, y: distance)); view.scroll.reflectScrolledClipView(view.scroll.contentView) }
        window.orderFront(nil); window.display(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25)); view.displayIfNeeded()
        for scale in [1,2] { let rect = view.bounds; guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(rect.width)*scale, pixelsHigh: Int(rect.height)*scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }; rep.size = rect.size
            if name == "empty" { view.cacheDisplay(in: rect, to: rep) } else if let ctx = NSGraphicsContext(bitmapImageRep: rep) { NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx; view.layer?.render(in: ctx.cgContext); NSGraphicsContext.restoreGraphicsState() }
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: "\(path)/\(name)-\(scale)x.png")) } }
        window.orderOut(nil)
    }
    let caseName = CommandLine.arguments.firstIndex(of: "--case").flatMap { $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1] : nil }
    if caseName == nil || caseName == "overview" { capture("overview", ["demo":rec], "demo") }
    var legacy = payload; legacy.removeValue(forKey: "checklist"); if caseName == nil || caseName == "legacy" { capture("legacy", ["demo":["id":"demo", "status":legacy, "updatedAt":now]], "demo") }
    if caseName == nil || caseName == "empty" { capture("empty", [:], nil) }
    var invalid = payload; invalid["checklist"] = [["id":"broken", "title":"Unknown", "done":1]]; if caseName == nil || caseName == "invalid" { capture("invalid", ["demo":["id":"demo", "status":invalid, "updatedAt":now]], "demo") }
    var long = payload; long["goal"] = String(repeating:"A longer fictional goal for testing wrapping. ", count: 8); long["checklist"] = (1...12).map { ["id":"item-\($0)", "title":"Milestone \($0) with a longer description for scrolling", "done":false] as [String : Any] }; if caseName == nil || caseName == "long" { capture("long", ["demo":["id":"demo", "status":long, "updatedAt":now]], "demo") }; if caseName == nil || caseName == "long-bottom" { capture("long-bottom", ["demo":["id":"demo", "status":long, "updatedAt":now]], "demo", bottom: true) }
}
if let i = CommandLine.arguments.firstIndex(of: "--preview"), i+1 < CommandLine.arguments.count { preview(CommandLine.arguments[i+1]) } else { let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run() }
