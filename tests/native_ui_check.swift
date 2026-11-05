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
    guard let details = descendants(view).compactMap({ $0 as? NSButton }).first(where: { $0.title == "Details" }) else { fatalError("missing details") }; details.performClick(nil); precondition(has("Coverage · Fixture coverage"), "details did not expose coverage")

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
    let delegate = AppDelegate(); delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)); precondition(delegate.status.length == NSStatusItem.squareLength && delegate.status.button?.image?.isTemplate == true && delegate.status.button?.action == #selector(AppDelegate.toggle) && delegate.status.button?.target === delegate)
    let icon = delegate.status.button!.image!; precondition(icon.size.width > 0 && icon.size.width <= 20); print("Native checks passed: stable identity, current default, collapse, refresh, project switch, expansion, invalid/legacy and icon target/size.")
    window.orderOut(nil); NSStatusBar.system.removeStatusItem(delegate.status); testDefaults.removePersistentDomain(forName: testDomain)
}
