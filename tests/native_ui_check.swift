func runNativeChecks() {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let view = Overview(); let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false); window.contentView = view
    let child: [String: Any] = ["id":"child", "title":"Child marker", "done":false]
    let projectA: [String: Any] = ["id":"a", "updatedAt":"2026-11-06T00:00:00Z", "status":["name":"Same", "goal":"Goal", "checkpoint":"Checkpoint A", "status":"Active", "tokenUsage":["estimate":1000,"scope":"linked-chat","source":"Fixture source","coverage":"Fixture coverage"], "currentMilestoneID":"parent", "checklist":[["id":"parent", "title":"Parent", "done":false, "children":[child]]]]]
    let projectB: [String: Any] = ["id":"b", "updatedAt":"2026-11-06T00:00:00Z", "status":["name":"Same", "goal":"Goal", "checkpoint":"Checkpoint B", "status":"Active", "checklist":[["id":"other", "title":"Other", "done":false]]]]
    func descendants(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(descendants) }
    func has(_ text: String) -> Bool { descendants(view.body).compactMap { $0 as? NSTextField }.contains { $0.stringValue == text } }
    func disclosure() -> NSButton? { descendants(view.body).compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "parent" } }
    func freshNextHasDisclosure(_ next: String) -> Bool {
        let fresh = Overview(); let freshWindow = NSWindow(contentRect: fresh.frame, styleMask: [.titled], backing: .buffered, defer: false); freshWindow.contentView = fresh
        var record = projectA; var status = record["status"] as! [String: Any]; status["next"] = next; record["status"] = status
        fresh.render(projects:["a":record], selected:"a", unavailable:false)
        fresh.layoutSubtreeIfNeeded(); return descendants(fresh.body).compactMap { $0 as? NSButton }.contains { $0.title == "Show full" }
    }
    precondition(!freshNextHasDisclosure("Connect one assistant, then verify a saved update."), "fresh one-line Next incorrectly disclosed")
    precondition(!freshNextHasDisclosure("First line has a sensible amount of content.\nSecond line has a sensible amount of content.\nThird line has a sensible amount of content."), "fresh three-line Next incorrectly disclosed")
    precondition(freshNextHasDisclosure("First line has a sensible amount of content.\nSecond line has a sensible amount of content.\nThird line has a sensible amount of content.\nFourth line."), "fresh four-line Next did not disclose")
    precondition(!freshNextHasDisclosure(Array(repeating: "checkpoint", count: 15).joined(separator: " ")), "three wrapped lines incorrectly disclosed")
    precondition(freshNextHasDisclosure(Array(repeating: "checkpoint", count: 20).joined(separator: " ")), "four wrapped lines not disclosed")
    view.render(projects:["a":projectA,"b":projectB], selected:"a", unavailable:false); view.layoutSubtreeIfNeeded(); window.orderFront(nil); window.display(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    precondition(view.picker.numberOfItems == 2 && view.picker.itemArray.map { $0.representedObject as? String } == ["a", "b"])
    precondition(has("Child marker") && has("Parent  ·  Current"), "current branch did not expand or identify current")
    precondition(has("Checkpoint") && has("Next"), "field labels missing")
    precondition(has("0 of 1 milestones complete") && !has("Progress"), "milestone count missing or duplicated")
    precondition(!has("Linked chat · ≈1.0K tokens · Project total not measured"), "usage displayed outside Details")
    precondition(view.scroll.scrollerStyle == .legacy && view.scroll.bounds.width - view.scroll.contentSize.width >= 10, "scroll gutter is not reserved")
    guard let allProjects = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "All projects" }) else { fatalError("all projects action missing") }
    allProjects.performClick(nil); precondition(has("Checkpoint A") && has("Checkpoint B"), "all projects did not show both checkpoints")
    guard let projectButton = descendants(view.body).compactMap({ $0 as? NSButton }).first(where: { $0.identifier?.rawValue == "a" }) else { fatalError("project selection missing") }; projectButton.performClick(nil); precondition(has("Child marker"), "project selection did not open selected project")
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("glance-test-" + UUID().uuidString)); defer { pasteboard.releaseGlobally() }
    let expected = "Add this project to Glance. Read the Glance agent guide at \"\(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AgentGuide.md").path)\", use the updater at \"\(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/glance-store").path)\", and ask if the project identity is unclear. Add only this project and confirm the saved result."
    precondition(writeSetupPrompt(view.addProjectPrompt(), to: pasteboard) && pasteboard.string(forType: .string) == expected, "actual pasteboard prompt differs")
    var copied = ""; view.onCopyPrompt = { copied = $0; return true }; view.openHelp()
    precondition(has("Using Glance"), "help did not open")
    precondition(view.picker.isHidden && view.headerHelp.title == "Back", "help navigation should hide picker and provide one Back")
    guard let copy = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Copy setup prompt" }) else { fatalError("missing copy") }; copy.performClick(nil)
    precondition(copied.contains("Contents/Resources/AgentGuide.md") && copied.contains("Contents/MacOS/glance-store") && has("Copied. Paste it into your assistant."), "copy prompt or confirmation missing")
    view.onCopyPrompt = { _ in false }; copy.performClick(nil); precondition(has("Could not copy. Try again."), "copy failure missing")
    precondition(view.headerHelp.action == #selector(Overview.closeHelp), "header back unavailable"); view.headerHelp.performClick(nil); precondition(!view.helpMode && view.headerHelp.action == #selector(Overview.openHelp) && has("Child marker"), "header back did not restore overview")

    guard let details = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Details" }) else { fatalError("missing details") }; details.performClick(nil); precondition(has("Fixture coverage") && has("Linked chat · ≈1.0K tokens · Project total not measured"), "details did not expose usage and coverage")

    var healthProject = projectA; var healthStatus = healthProject["status"] as! [String: Any]; healthStatus["health"] = ["state":"waiting-on-you", "reason":"Awaiting a decision"]; healthProject["status"] = healthStatus; healthProject["updatedBySession"] = "codex-example"
    view.render(projects:["a":healthProject], selected:"a", unavailable:false)
    precondition(has("Waiting on you") && has("Awaiting a decision") && has("SAVED AT") && !has("Saved health: Waiting on you · age above is time since save"), "health or saver presentation missing")
    precondition(!has("codex-example") && has("Goal"), "friendly saved time or goal missing")
    guard let technical = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Technical details" }) else { fatalError("technical details missing") }; technical.performClick(nil)
    precondition(has("2026-11-06T00:00:00Z") && has("codex-example"), "technical details did not expose timestamp and session ID")
    var features = projectA; var featureStatus = features["status"] as! [String: Any]
    featureStatus["checkpointClosure"] = ["state":"complete", "finishCondition":"Pass review", "evidence":"Review passed"]
    featureStatus["effortRange"] = ["min":2, "max":4, "unit":"hours", "source":"Prior work", "coverage":"Current checkpoint"]
    featureStatus["recurring"] = ["current":"November", "last":"October complete", "next":"December", "source":"User"]
    featureStatus["externalWait"] = ["reason":"Waiting for reviewer", "source":"Review request"]
    features["status"] = featureStatus
    view.render(projects:["a":features], selected:"a", unavailable:false)
    precondition(has("Pass review") && has("Review passed"), "checkpoint closure details missing")
    precondition(has("2–4 hours") && has("Prior work"), "effort range details missing")
    precondition(has("November") && has("October complete") && has("December"), "recurring cycle details missing")
    precondition(has("Waiting for reviewer") && has("Review request"), "external wait details missing")
    var longNext = projectA; var nextStatus = longNext["status"] as! [String: Any]; let fullNext = Array(repeating: "A detailed next action with its exact spacing.", count: 12).joined(separator: "  "); nextStatus["next"] = fullNext; longNext["status"] = nextStatus
    nextStatus["next"] = "First line\nSecond line\nThird line"; longNext["status"] = nextStatus
    view.render(projects:["a":longNext], selected:"a", unavailable:false); precondition(!descendants(view.body).compactMap({ $0 as? NSButton }).contains(where: { $0.title == "Show full" }), "three lines should not disclose")
    nextStatus["next"] = "First line\nSecond line\nThird line\nFourth line"; longNext["status"] = nextStatus
    view.render(projects:["a":longNext], selected:"a", unavailable:false); precondition(descendants(view.body).compactMap({ $0 as? NSButton }).contains(where: { $0.title == "Show full" }), "four lines should disclose")
    nextStatus["next"] = fullNext; longNext["status"] = nextStatus; view.render(projects:["a":longNext], selected:"a", unavailable:false)
    guard let showFull = descendants(view.body).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Show full" }) else { fatalError("long next action missing disclosure") }; showFull.performClick(nil); precondition(has(fullNext), "full next action changed"); precondition((window.firstResponder as? NSButton)?.title == "Show less", "next disclosure lost focus")
    view.ageLabel?.stringValue = "outdated"; view.render(projects:["a":longNext], selected:"a", unavailable:false); precondition(view.ageLabel?.stringValue != "outdated", "unchanged refresh did not update saved age")
    let priorScroll = view.scroll.contentView.bounds.origin
    var renamedB = projectB; var renamedStatus = renamedB["status"] as! [String: Any]; renamedStatus["name"] = "Renamed"; renamedB["status"] = renamedStatus
    view.render(projects:["a":projectA,"b":renamedB], selected:"a", unavailable:false)
    precondition(view.picker.itemArray.contains { $0.title == "Renamed" } && view.picker.selectedItem?.representedObject as? String == "a" && has("Child marker") && view.scroll.contentView.bounds.origin == priorScroll, "other project rename did not refresh picker safely")
    guard let button = disclosure() else { fatalError("missing disclosure") }; button.performClick(nil); precondition(!has("Child marker"), "collapse failed")
    view.render(projects:["a":projectA,"b":projectB], selected:"a", unavailable:false); precondition(!has("Child marker"), "refresh lost collapse")
    view.render(projects:["a":projectA,"b":projectB], selected:"b", unavailable:false); precondition(view.picker.selectedItem?.representedObject as? String == "b")
    view.render(projects:["a":projectA,"b":projectB], selected:"a", unavailable:false); precondition(!has("Child marker"), "switch lost collapse")
    guard let again = disclosure() else { fatalError("missing disclosure") }; again.performClick(nil); precondition(has("Child marker"), "expand failed")
    var bad = projectA["status"] as! [String: Any]; bad["tokenUsage"] = ["estimate":true, "source":"s", "coverage":"c"]; if case .invalid = checklist(bad) {} else { fatalError("invalid usage accepted") }
    bad.removeValue(forKey:"tokenUsage"); bad.removeValue(forKey:"checklist"); bad.removeValue(forKey:"currentMilestoneID"); if case .missing = checklist(bad) {} else { fatalError("legacy not missing") }
    var long = projectA; var longData = long["status"] as! [String: Any]; longData.removeValue(forKey:"currentMilestoneID"); longData["checklist"] = (1...30).map { ["id":"item\($0)", "title":"Milestone \($0)", "done":false] as [String : Any] }; long["status"] = longData
    view.render(projects:["a":long], selected:"a", unavailable:false); view.layoutSubtreeIfNeeded(); let maxScroll = view.body.frame.height - view.scroll.contentSize.height; precondition(maxScroll > 20); view.scroll.contentView.scroll(to:NSPoint(x:0,y:20)); let offset = view.scroll.contentView.bounds.origin.y
    view.render(projects:["a":long], selected:"a", unavailable:false); precondition(view.scroll.contentView.bounds.origin.y == offset, "unchanged refresh moved scroll")
    var aged = projectA; aged["updatedAt"] = "2000-01-01T00:00:00Z"; view.render(projects:["a":aged], selected:"a", unavailable:true)
    precondition(view.ageLabel!.textColor == .systemOrange && view.notice.stringValue.contains("Unavailable"), "stale or unavailable warning missing")
    aged["updatedAt"] = "2999-01-01T00:00:00Z"; view.render(projects:["a":aged], selected:"a", unavailable:false)
    precondition(view.ageLabel!.stringValue.contains("Clock mismatch"), "future date warning missing")
    aged["updatedAt"] = "invalid"; view.render(projects:["a":aged], selected:"a", unavailable:false)
    precondition(has("Checkpoint saved time unknown"), "unknown date warning missing")
    view.showAllProjects(); precondition(view.ageLabel == nil, "all-projects should not show selected age")
    let root = URL(fileURLWithPath: CommandLine.arguments[CommandLine.arguments.firstIndex(of: "--store")! + 1], isDirectory: true); try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let initial = AppDelegate(); initial.refresh()
    precondition(!initial.unavailable && initial.overview.picker.isHidden && descendants(initial.overview.body).compactMap({ $0 as? NSButton }).contains(where: { $0.title == "Copy setup prompt" }), "missing store did not offer setup")
    try! Data("{".utf8).write(to: root.appendingPathComponent("store.json")); initial.refresh()
    precondition(initial.unavailable && !descendants(initial.overview.body).compactMap({ $0 as? NSButton }).contains(where: { $0.title == "Copy setup prompt" }), "corrupt store showed empty setup")
    try! FileManager.default.removeItem(at: root.appendingPathComponent("store.json"))
    let validRecord: [String: Any] = ["id":"a", "schema":1, "version":1, "request":"request", "sessions":["session"], "status":projectA["status"]!]
    let backup = try! JSONSerialization.data(withJSONObject: ["schema":1, "projects":["a":validRecord]])
    try! backup.write(to: root.appendingPathComponent("store.backup.json")); let broken = Data("{".utf8); try! broken.write(to: root.appendingPathComponent("store.json"))
    let validationDelegate = AppDelegate()
    for (field, value) in [("schema", true), ("recordSchema", true), ("version", true), ("version", -1), ("version", 1.5), ("version", Int.max)] as [(String, Any)] {
        var record = validRecord; var envelope: [String: Any] = ["schema": 1, "projects": ["a": record]]
        if field == "schema" { envelope["schema"] = value } else { record[field == "recordSchema" ? "schema" : "version"] = value; envelope["projects"] = ["a": record] }
        try! JSONSerialization.data(withJSONObject: envelope).write(to: root.appendingPathComponent("invalid.json"))
        precondition(validationDelegate.readValidated(root.appendingPathComponent("invalid.json")) == nil, "invalid numeric record accepted")
        try! JSONSerialization.data(withJSONObject: envelope).write(to: root.appendingPathComponent("store.backup.json")); let fallback = AppDelegate(); fallback.refresh(); precondition(fallback.unavailable && !fallback.usingBackup && fallback.cached.isEmpty, "invalid backup accepted")
    }
    try! backup.write(to: root.appendingPathComponent("store.backup.json"))
    let removal = AppDelegate(); try! backup.write(to: root.appendingPathComponent("store.json")); removal.refresh(); try! FileManager.default.removeItem(at: root.appendingPathComponent("store.json")); removal.refresh(); precondition(removal.unavailable && removal.hasSnapshot && !removal.cached.isEmpty, "removed store lost snapshot or showed empty setup")
    try! broken.write(to: root.appendingPathComponent("store.json"))
    let delegate = AppDelegate(); delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)); precondition(delegate.status.length == NSStatusItem.squareLength && delegate.status.button?.image?.isTemplate == true && delegate.status.button?.action == #selector(AppDelegate.toggle) && delegate.status.button?.target === delegate)
    precondition(delegate.usingBackup && delegate.unavailable && delegate.cached["a"] != nil, "valid backup not displayed"); precondition((try! Data(contentsOf: root.appendingPathComponent("store.json"))) == broken, "viewer changed corrupt primary")
    try! backup.write(to: root.appendingPathComponent("store.json")); delegate.wake()
    precondition(!delegate.unavailable && !delegate.usingBackup && delegate.cached["a"] != nil && delegate.watcher != nil, "simulated wake did not reload and attach watcher")
    var corruptStatus = validRecord; var corruptFields = corruptStatus["status"] as! [String: Any]; corruptFields["checkpointClosure"] = ["state":"complete", "finishCondition":"No evidence"]; corruptStatus["status"] = corruptFields
    try! JSONSerialization.data(withJSONObject: ["schema":2, "projects":["a":corruptStatus]]).write(to: root.appendingPathComponent("store.json"))
    func waitFor(_ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 2)
        while !condition() && Date() < deadline { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02)) }
        return condition()
    }
    func monitorsReady() -> Bool { delegate.popover.isShown && delegate.localMouseMonitor != nil && delegate.globalMouseMonitor != nil }
    func assertMonitorsReady(_ context: String) {
        let ready = waitFor(monitorsReady)
        precondition(ready, "\(context): shown=\(delegate.popover.isShown), local=\(delegate.localMouseMonitor != nil), global=\(delegate.globalMouseMonitor != nil)")
    }
    delegate.showPopover(); precondition(delegate.overview.notice.stringValue == "Unavailable · showing last saved view", "invalid record was displayed as available")
    assertMonitorsReady("initial show")
    func mouseDown(_ target: NSWindow, _ point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: target.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
    }
    let popoverWindow = delegate.overview.window!
    NSApp.sendEvent(mouseDown(popoverWindow, NSPoint(x: 10, y: 10)))
    precondition(delegate.popover.isShown, "inside click closed popover")
    let statusButton = delegate.status.button!
    delegate.dismissForLocalMouseDown(mouseDown(statusButton.window!, statusButton.convert(NSPoint(x: statusButton.bounds.midX, y: statusButton.bounds.midY), to: nil)))
    precondition(delegate.popover.isShown, "status click closed before toggle")
    delegate.toggle(); precondition(waitFor { !delegate.popover.isShown && delegate.localMouseMonitor == nil && delegate.globalMouseMonitor == nil }, "toggle did not close and clean up")
    delegate.toggle(); assertMonitorsReady("toggle reopen")
    NSApp.sendEvent(mouseDown(window, NSPoint(x: 10, y: 10)))
    precondition(waitFor { !delegate.popover.isShown && delegate.localMouseMonitor == nil && delegate.globalMouseMonitor == nil }, "outside event did not close and clean up")
    delegate.popoverDidShow(Notification(name: NSPopover.didShowNotification))
    precondition(delegate.localMouseMonitor == nil && delegate.globalMouseMonitor == nil, "late show callback installed monitors after close")
    delegate.showPopover(); delegate.popover.performClose(nil)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    precondition(waitFor { !delegate.popover.isShown && delegate.localMouseMonitor == nil && delegate.globalMouseMonitor == nil }, "rapid close left monitors installed")
    delegate.removeMouseMonitors(); delegate.removeMouseMonitors()
    delegate.showPopover(); assertMonitorsReady("show before termination"); delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    precondition(delegate.localMouseMonitor == nil && delegate.globalMouseMonitor == nil, "termination did not clean up")
    delegate.popover.performClose(nil)
    let icon = delegate.status.button!.image!; precondition(icon.size.width > 0 && icon.size.width <= 20); print("Native checks passed: stable identity, current default, collapse, refresh, project switch, expansion, invalid/legacy and icon target/size.")
    window.orderOut(nil); NSStatusBar.system.removeStatusItem(delegate.status); testDefaults.removePersistentDomain(forName: testDomain)
}
