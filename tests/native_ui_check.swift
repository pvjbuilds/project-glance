func runNativeChecks() {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let view = Overview(); let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false); window.contentView = view
    let child: [String: Any] = ["id":"child", "title":"Child marker", "done":false]
    let projectA: [String: Any] = ["id":"a", "updatedAt":"2026-11-06T00:00:00Z", "status":["name":"Same", "goal":"Goal", "checkpoint":"Checkpoint A", "status":"Active", "tokenUsage":["estimate":1000,"scope":"linked-chat","source":"Fixture source","coverage":"Fixture coverage"], "currentMilestoneID":"parent", "checklist":[["id":"parent", "title":"Parent", "done":false, "children":[child]]]]]
    let projectB: [String: Any] = ["id":"b", "updatedAt":"2026-11-06T00:00:00Z", "status":["name":"Same", "goal":"Goal", "checkpoint":"Checkpoint B", "status":"Active", "checklist":[["id":"other", "title":"Other", "done":false]]]]
    func descendants(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(descendants) }
    func has(_ text: String) -> Bool { descendants(view.body).compactMap { $0 as? NSTextField }.contains { $0.stringValue == text } }
    func disclosure() -> NSButton? { descendants(view.body).compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "parent" } }
    view.render(projects:["a":projectA,"b":projectB], selected:"a", unavailable:false); view.layoutSubtreeIfNeeded(); window.orderFront(nil); window.display(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    precondition(view.picker.numberOfItems == 2 && view.picker.itemArray.map { $0.representedObject as? String } == ["a", "b"])
    precondition(has("Child marker") && has("Parent  ·  Current"), "current branch did not expand or identify current")
    precondition(has("Checkpoint") && has("Next") && has("Goal"), "field labels missing")
    precondition(!has("Linked chat · ≈1.0K tokens · Project total not measured"), "usage displayed outside Details")
    precondition(view.scroll.scrollerStyle == .legacy && view.scroll.bounds.width - view.scroll.contentSize.width >= 10, "scroll gutter is not reserved")
    guard let allProjects = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "All projects" }) else { fatalError("all projects action missing") }
    allProjects.performClick(nil); precondition(has("Checkpoint A") && has("Checkpoint B"), "all projects did not show both checkpoints")
    guard let projectButton = descendants(view.body).compactMap({ $0 as? NSButton }).first(where: { $0.identifier?.rawValue == "a" }) else { fatalError("project selection missing") }; projectButton.performClick(nil); precondition(has("Child marker"), "project selection did not open selected project")
    var copied = ""; view.onCopyPrompt = { copied = $0 }; view.openHelp()
    precondition(has("Using Glance"), "help did not open")
    guard let copy = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Copy add-project prompt" }) else { fatalError("missing copy") }; copy.performClick(nil)
    precondition(copied.contains("Contents/Resources/AgentGuide.md") && copied.contains("Contents/MacOS/glance-store"), "copy prompt missing app paths")
    precondition(view.headerHelp.action == #selector(Overview.closeHelp), "header back unavailable"); view.headerHelp.performClick(nil); precondition(!view.helpMode && view.headerHelp.action == #selector(Overview.openHelp) && has("Child marker"), "header back did not restore overview")

    guard let details = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Details" }) else { fatalError("missing details") }; details.performClick(nil); precondition(has("Fixture coverage") && has("Linked chat · ≈1.0K tokens · Project total not measured"), "details did not expose usage and coverage")

    var healthProject = projectA; var healthStatus = healthProject["status"] as! [String: Any]; healthStatus["health"] = ["state":"waiting-on-you", "reason":"Awaiting a decision"]; healthProject["status"] = healthStatus; healthProject["updatedBySession"] = "codex-example"
    view.render(projects:["a":healthProject], selected:"a", unavailable:false)
    precondition(has("Waiting on you") && has("Awaiting a decision") && has("Last saved by: Codex session") && has("Saved health: Waiting on you · age above is time since save"), "health or saver presentation missing")
    precondition(has("codex-example"), "details did not expose session ID")
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
    let priorScroll = view.scroll.contentView.bounds.origin
    var renamedB = projectB; var renamedStatus = renamedB["status"] as! [String: Any]; renamedStatus["name"] = "Renamed"; renamedB["status"] = renamedStatus
    view.render(projects:["a":projectA,"b":renamedB], selected:"a", unavailable:false)
    precondition(view.picker.itemArray.contains { $0.title == "Renamed · b" } && view.picker.selectedItem?.representedObject as? String == "a" && has("Child marker") && view.scroll.contentView.bounds.origin == priorScroll, "other project rename did not refresh picker safely")
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
    let root = URL(fileURLWithPath: CommandLine.arguments[CommandLine.arguments.firstIndex(of: "--store")! + 1], isDirectory: true); try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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
    let delegate = AppDelegate(); delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)); precondition(delegate.status.length == NSStatusItem.squareLength && delegate.status.button?.image?.isTemplate == true && delegate.status.button?.action == #selector(AppDelegate.toggle) && delegate.status.button?.target === delegate)
    precondition(delegate.usingBackup && delegate.unavailable && delegate.cached["a"] != nil, "valid backup not displayed"); precondition((try! Data(contentsOf: root.appendingPathComponent("store.json"))) == broken, "viewer changed corrupt primary")
    try! backup.write(to: root.appendingPathComponent("store.json")); delegate.wake()
    precondition(!delegate.unavailable && !delegate.usingBackup && delegate.cached["a"] != nil && delegate.watcher != nil, "simulated wake did not reload and attach watcher")
    var corruptStatus = validRecord; var corruptFields = corruptStatus["status"] as! [String: Any]; corruptFields["checkpointClosure"] = ["state":"complete", "finishCondition":"No evidence"]; corruptStatus["status"] = corruptFields
    try! JSONSerialization.data(withJSONObject: ["schema":2, "projects":["a":corruptStatus]]).write(to: root.appendingPathComponent("store.json"))
    delegate.showPopover(); precondition(delegate.overview.notice.stringValue == "Unavailable · showing last saved view", "invalid record was displayed as available")
    let icon = delegate.status.button!.image!; precondition(icon.size.width > 0 && icon.size.width <= 20); print("Native checks passed: stable identity, current default, collapse, refresh, project switch, expansion, invalid/legacy and icon target/size.")
    window.orderOut(nil); NSStatusBar.system.removeStatusItem(delegate.status); testDefaults.removePersistentDomain(forName: testDomain)
}
