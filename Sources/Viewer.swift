import Cocoa
import ServiceManagement
import CoreFoundation

// JSON integers only; reject booleans, floating-point encodings and unsafe versions.
func strictInteger(_ raw: Any?, max: Int = 9_007_199_254_740_990) -> Int? {
    guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
          ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"].contains(String(cString: n.objCType)),
          let value = n as? Int, value >= 0, value <= max else { return nil }
    return value
}

struct TokenUsage { let estimate: Int64; let source: String; let coverage: String; let asOf: String?; let scope: String }
func usage(_ raw: Any, scopes: Set<String>, defaultScope: String) -> TokenUsage? {
    guard let obj = raw as? [String: Any], let n = obj["estimate"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue <= 9_007_199_254_740_991, n.doubleValue.rounded(.towardZero) == n.doubleValue,
        let source = obj["source"] as? String, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, source.count <= 2000, let coverage = obj["coverage"] as? String, !coverage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, coverage.count <= 2000 else { return nil }
    if let v = obj["asOf"] { guard let date = v as? String, !date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil } }
    let scope = obj["scope"] as? String ?? defaultScope; if obj["scope"] != nil && !(obj["scope"] is String) { return nil }; guard scopes.contains(scope) else { return nil }
    return TokenUsage(estimate: n.int64Value, source: source, coverage: coverage, asOf: obj["asOf"] as? String, scope: scope)
}
func health(_ data: [String: Any]) -> (String, String)? {
    guard let h = data["health"] as? [String: Any], let state = h["state"] as? String,
          let reason = h["reason"] as? String, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reason.count <= 2000 else { return nil }
    let labels = ["moving":"Moving", "waiting-on-you":"Waiting on you", "blocked":"Blocked", "parked":"Parked", "needs-scoping":"Needs scoping", "checkpoint-complete":"Checkpoint complete"]
    guard let title = labels[state] else { return nil }; return (title, reason)
}
func validExtras(_ payload: [String: Any]) -> Bool {
    func nonempty(_ raw: Any?) -> Bool { guard let s = raw as? String else { return false }; return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.count <= 2000 }
    if let raw = payload["checkpointClosure"] {
        guard let v = raw as? [String: Any], let state = v["state"] as? String, ["open", "complete"].contains(state), nonempty(v["finishCondition"]) else { return false }
        if state == "complete" && !nonempty(v["evidence"]) { return false }
        if let evidence = v["evidence"], (!(evidence is String) || (evidence as! String).count > 2000) { return false }
    }
    if let raw = payload["effortRange"] {
        guard let v = raw as? [String: Any], let min = strictInteger(v["min"]), let max = strictInteger(v["max"]), min <= max, let unit = v["unit"] as? String, ["minutes", "hours", "days"].contains(unit), nonempty(v["source"]), nonempty(v["coverage"]) else { return false }
    }
    if let raw = payload["externalWait"] { guard let v = raw as? [String: Any], nonempty(v["reason"]), nonempty(v["source"]) else { return false } }
    if let raw = payload["recurring"] {
        guard let v = raw as? [String: Any], nonempty(v["current"]), nonempty(v["source"]) else { return false }
        for key in ["last", "next"] { if let value = v[key], !nonempty(value) { return false } }
    }
    return true
}
struct Milestone { let id: String; let title: String; let done: Bool; let children: [Milestone]; let tokens: TokenUsage? }
enum Checklist { case items([Milestone]), missing, invalid }
func checklist(_ data: [String: Any]) -> Checklist {
    if let raw = data["tokenUsage"], usage(raw, scopes: ["project", "linked-chat"], defaultScope: "project") == nil { return .invalid }
    guard let raw = data["checklist"] else { return data["currentMilestoneID"] == nil ? .missing : .invalid }
    guard let list = raw as? [[String: Any]] else { return .invalid }
    var ids = Set<String>(), pending = Set<String>(), count = 0
    func parse(_ nodes: [[String: Any]], _ depth: Int) -> [Milestone]? {
        guard depth <= 4 else { return nil }; var result: [Milestone] = []
        for item in nodes {
            count += 1
            guard count <= 200, let id = item["id"] as? String, id.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil, ids.insert(id).inserted,
                  let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let value = item["done"] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
            if !value.boolValue { pending.insert(id) }
            var children: [Milestone] = []
            if let rawChildren = item["children"] { guard let array = rawChildren as? [[String: Any]] else { return nil }; if !array.isEmpty { guard let parsed = parse(array, depth + 1) else { return nil }; children = parsed } }
            if value.boolValue && children.contains(where: { !$0.done }) { return nil }
            let token: TokenUsage? = item["tokenUsage"].flatMap { usage($0, scopes: ["task"], defaultScope: "task") }; if item["tokenUsage"] != nil && token == nil { return nil }
            result.append(Milestone(id: id, title: title, done: value.boolValue, children: children, tokens: token))
        }
        return result
    }
    guard let result = parse(list, 1) else { return .invalid }
    if let current = data["currentMilestoneID"] { guard let id = current as? String, pending.contains(id) else { return .invalid } }
    return .items(result)
}
func tokensText(_ u: TokenUsage) -> String {
    let n = Double(u.estimate); let formatted: String
    if n >= 1_000_000 { formatted = String(format: "%.1fM", n / 1_000_000) } else if n >= 1_000 { formatted = String(format: "%.1fK", n / 1_000) } else { formatted = u.estimate.formatted() }
    return "≈\(formatted) tokens"
}
func tokenDetails(_ u: TokenUsage) -> String { "Source: \(u.source)" + (u.asOf.map { " · As of \($0)" } ?? "") }
func defaultExpanded(_ nodes: [Milestone], current: String?) -> Set<String> {
    guard let current else { return [] }; func find(_ items: [Milestone], _ path: [String]) -> [String]? { for n in items { let next = path + (n.children.isEmpty ? [] : [n.id]); if n.id == current { return next }; if let found = find(n.children, next) { return found } }; return nil }; return Set(find(nodes, []) ?? [])
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

func fieldRow(_ title: String, _ value: String) -> NSStackView {
    let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.spacing = 8
    let chip = NSStackView(); chip.orientation = .horizontal; chip.alignment = .centerY; chip.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6); chip.wantsLayer = true; chip.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor; chip.layer?.cornerRadius = 5
    chip.addArrangedSubview(label(title, size: 10, weight: .semibold, color: .white)); chip.widthAnchor.constraint(equalToConstant: 78).isActive = true
    let text = label(value, size: 12); row.addArrangedSubview(chip); row.addArrangedSubview(text); text.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -86).isActive = true
    return row
}
func detailRow(_ title: String, _ value: String) -> NSStackView {
    let group = column(3); addFull(label(title, size: 10, weight: .semibold, color: muted), to: group); let content = label(value, size: 11); content.isSelectable = true; addFull(content, to: group); return group
}


// Break long source text at whitespace, preserving every word and respecting supplied lines.
func detailGroups(_ title: String, _ value: String) -> NSStackView {
    let group = column(5); addFull(label(title, size: 10, weight: .semibold, color: muted), to: group)
    for line in value.components(separatedBy: "\n") {
        var words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init), chunks: [String] = []
        while !words.isEmpty {
            var chunk = words.removeFirst()
            while let next = words.first, chunk.count + next.count + 1 <= 140 { chunk += " " + words.removeFirst() }
            chunks.append(chunk)
        }
        if chunks.isEmpty { chunks = [""] }
        for chunk in chunks { let item = label(chunk, size: 11); item.isSelectable = true; addFull(item, to: group) }
    }
    return group
}

final class TopClipView: NSClipView { override var isFlipped: Bool { true } }
final class Overview: NSView {
    let headerHelp = NSButton(); let picker = NSPopUpButton(); let body = column(10); let scroll = NSScrollView(); let notice = label("", size: 11, color: .systemOrange)
    var allProjectsMode = false
    var recoveredBackup = false; var helpMode = false; var onCopyPrompt: ((String) -> Void)?; var lastProjects: [String: [String: Any]] = [:]; var lastSelected: String?; var lastUnavailable = false; var lastSignature: Data?; var lastDisplayedID: String?; var freshnessLabel: NSTextField?
    var onSelect: ((String) -> Void)?; var onSettings: (() -> Void)?; var onQuit: (() -> Void)?; var onContext: (() -> Void)?
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 570)); wantsLayer = true; layer?.backgroundColor = shell.cgColor
        appearance = NSAppearance(named: .darkAqua)
        let title = NSStackView(); title.orientation = .horizontal; title.alignment = .centerY; title.spacing = 8
        let mark = NSImageView(); mark.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil); mark.contentTintColor = .white; mark.widthAnchor.constraint(equalToConstant: 20).isActive = true; mark.heightAnchor.constraint(equalToConstant: 20).isActive = true; title.addArrangedSubview(mark); title.addArrangedSubview(label("Glance", size: 17, weight: .semibold)); let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); title.addArrangedSubview(spacer); let help = headerHelp; help.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help"); help.isBordered = false; help.target = self; help.action = #selector(openHelp); help.toolTip = "How to use Glance"; help.setAccessibilityLabel("Help"); title.addArrangedSubview(help)
        picker.target = self; picker.action = #selector(selection); picker.controlSize = .large
        scroll.contentView = TopClipView(); scroll.contentView.clipsToBounds = true; scroll.clipsToBounds = true; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .legacy; scroll.autohidesScrollers = false; scroll.drawsBackground = false; scroll.borderType = .noBorder
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
    @objc func selection() { allProjectsMode = false; lastSignature = nil; if let id = picker.selectedItem?.representedObject as? String { onSelect?(id) } }
    @objc func showAllProjects() { allProjectsMode = true; lastSignature = nil; render(projects: lastProjects, selected: lastSelected, unavailable: lastUnavailable) }
    @objc func selectProject(_ sender: NSButton) { guard let id = sender.identifier?.rawValue else { return }; allProjectsMode = false; lastSignature = nil; if let onSelect { onSelect(id) } else { render(projects: lastProjects, selected: id, unavailable: lastUnavailable) } }
    @objc func settingsClicked() { onSettings?() }
    @objc func quitClicked() { onQuit?() }
    @objc func contextClicked() { onContext?() }
    @objc func openHelp() { helpMode = true; headerHelp.image = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: "Back to projects"); headerHelp.action = #selector(closeHelp); headerHelp.toolTip = "Back to projects"; headerHelp.setAccessibilityLabel("Back to projects"); showHelp() }
    @objc func closeHelp() { helpMode = false; headerHelp.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help"); headerHelp.action = #selector(openHelp); headerHelp.toolTip = "How to use Glance"; headerHelp.setAccessibilityLabel("Help"); lastSignature = nil; render(projects: lastProjects, selected: lastSelected, unavailable: lastUnavailable) }
    @objc func copyPrompt() { onCopyPrompt?(addProjectPrompt()) }
    func addProjectPrompt() -> String {
        let root = Bundle.main.bundleURL; let guide = root.appendingPathComponent("Contents/Resources/AgentGuide.md").path; let updater = root.appendingPathComponent("Contents/MacOS/glance-store").path
        return "Add this project to Glance. Read the Glance agent guide at \"\(guide)\", use the updater at \"\(updater)\", and ask if the project identity is unclear. Add only this project and confirm the saved result."
    }
    func showHelp() {
        picker.isEnabled = false; notice.stringValue = ""; body.arrangedSubviews.forEach { body.removeArrangedSubview($0); $0.removeFromSuperview() }
        let group = card(); addFull(label("Using Glance", size: 15, weight: .semibold), to: group)
        addFull(detailRow("ADD A PROJECT", "Ask an assistant to add the current project. Use the prompt below; projects are added only when you request them."), to: group)
        let copy = NSButton(title: "Copy add-project prompt", target: self, action: #selector(copyPrompt)); copy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil); copy.imagePosition = .imageLeading; group.addArrangedSubview(copy)
        addFull(detailRow("CONTINUE A PROJECT", "Tell the assistant to connect this session to the existing project before it updates the saved overview."), to: group)
        addFull(detailRow("MILESTONES", "The current branch opens first. Expand other branches to see substeps; completion is maintained by the associated assistant."), to: group)
        addFull(detailRow("FRESHNESS & USAGE", "Age and unavailable notices describe saved data. Token estimates include their scope and coverage; open Details for provenance."), to: group)
        addFull(detailRow("OPEN AT LOGIN", "Settings offers an optional macOS login item. It stays off unless you choose to enable it."), to: group)
        addFull(detailRow("AVAILABILITY", "The copied prompt points to this app’s guide and updater. Automatic chat recognition depends on a separately installed integration."), to: group)
        let back = NSButton(title: "Back to projects", target: self, action: #selector(closeHelp)); group.addArrangedSubview(back); addFull(group, to: body); scroll.contentView.scroll(to: .zero); layoutSubtreeIfNeeded()
    }
    @objc func toggleDetails(_ sender: NSButton) {
        guard let project = lastDisplayedID else { return }; UserDefaults.standard.set(sender.state == .on, forKey: "glance.details." + project)
        lastSignature = nil; render(projects: lastProjects, selected: lastSelected, unavailable: lastUnavailable)
    }
    @objc func toggleBranch(_ sender: NSButton) {
        guard let project = lastDisplayedID, let id = sender.identifier?.rawValue else { return }
        let key = "glance.expansion." + project; var choices = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]; choices[id] = sender.state == .on; UserDefaults.standard.set(choices, forKey: key)
        lastSignature = nil; render(projects: lastProjects, selected: lastSelected, unavailable: lastUnavailable)
    }
    func render(projects: [String: [String: Any]], selected: String?, unavailable: Bool) {
        if helpMode { lastProjects = projects; lastSelected = selected; lastUnavailable = unavailable; return }; picker.isEnabled = true
        let ids = projects.keys.sorted(), selectedID = selected.flatMap { projects[$0] != nil ? $0 : nil } ?? ids.first
        lastProjects = projects; lastSelected = selected; lastUnavailable = unavailable
        let record = selectedID.flatMap { projects[$0] }
        let names = ids.map { key -> [String: String] in let data = projects[key]?["status"] as? [String: Any]; return ["id": key, "name": data?["name"] as? String ?? key] }
        let signatureObject: [String: Any] = ["projects": names, "selected": selectedID ?? "", "record": record ?? [:], "unavailable": unavailable, "backup": recoveredBackup]
        let signature = try? JSONSerialization.data(withJSONObject: signatureObject, options: [.sortedKeys])
        func freshness(_ record: [String: Any]?) -> String {
            let updated = record?["updatedAt"] as? String ?? ""; let date = ISO8601DateFormatter().date(from: updated)
            let age = date.map { d -> String in let seconds = Date().timeIntervalSince(d); if seconds < -60 { return "clock mismatch · future timestamp" }; if seconds < 60 { return "just now" }; return RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()) } ?? "unknown"
            let stale = date.map { Date().timeIntervalSince($0) > 7*86400 } ?? true; return "\(stale ? "STALE  ·  " : "")Updated \(age)"
        }
        if let signature, signature == lastSignature { freshnessLabel?.stringValue = freshness(record); return }
        let previousOffset = scroll.contentView.bounds.origin; let preserve = selectedID == lastDisplayedID
        lastSignature = signature; lastDisplayedID = selectedID
        picker.removeAllItems()
        for id in ids { let data = projects[id]?["status"] as? [String: Any]; let name = data?["name"] as? String ?? id; let item = NSMenuItem(title: "\(name) · \(id)", action: nil, keyEquivalent: ""); item.representedObject = id; picker.menu?.addItem(item) }
        if let selectedID, let item = picker.itemArray.first(where: { $0.representedObject as? String == selectedID }) { picker.select(item) }
        notice.stringValue = recoveredBackup ? "Current data unavailable · showing previous backup" : (unavailable ? (projects.isEmpty ? "Saved data unavailable" : "Unavailable · showing last saved view") : "")
        body.arrangedSubviews.forEach { body.removeArrangedSubview($0); $0.removeFromSuperview() }; freshnessLabel = nil
        if allProjectsMode && !ids.isEmpty {
            for id in ids {
                guard let data = projects[id]?["status"] as? [String: Any] else { continue }
                let group = card(); let name = data["name"] as? String ?? id
                let button = NSButton(title: name + " · " + id, target: self, action: #selector(selectProject(_:))); button.identifier = NSUserInterfaceItemIdentifier(id); group.addArrangedSubview(button)
                addFull(label(data["checkpoint"] as? String ?? "Checkpoint unavailable", size: 12), to: group)
                addFull(label(health(data)?.0 ?? "Health not recorded", size: 11, color: muted), to: group)
                addFull(group, to: body)
            }
            return
        }
        guard let id = selectedID, let record else { addFull(label(unavailable ? "Project status is unavailable." : "No projects enrolled.", color: muted), to: body); return }
        guard let data = record["status"] as? [String: Any], let goal = data["goal"] as? String, let checkpoint = data["checkpoint"] as? String, let status = data["status"] as? String else { addFull(label("Project status is invalid or unavailable.", color: .systemOrange), to: body); return }
        let allButton = NSButton(title: "All projects", target: self, action: #selector(showAllProjects)); body.addArrangedSubview(allButton)
        let overview = card(); addFull(label(status, size: 13, weight: .semibold), to: overview)
        if let (state, reason) = health(data) {
            let badge = NSStackView(); badge.orientation = .horizontal; badge.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            badge.wantsLayer = true; badge.layer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor; badge.layer?.cornerRadius = 7
            badge.addArrangedSubview(label(state, size: 11, weight: .semibold)); overview.addArrangedSubview(badge)
            addFull(label(reason, size: 12), to: overview)
        }
        addFull(fieldRow("Checkpoint", checkpoint), to: overview)
        addFull(fieldRow("Next", (data["next"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Not provided"), to: overview)
        addFull(fieldRow("Goal", goal), to: overview)

        let detailed = UserDefaults.standard.bool(forKey: "glance.details." + id)
        let details = NSButton(title: detailed ? "Hide details" : "Details", target: self, action: #selector(toggleDetails(_:))); details.setButtonType(.toggle); details.state = detailed ? .on : .off; details.isBordered = false; details.image = NSImage(systemSymbolName: detailed ? "chevron.down" : "chevron.right", accessibilityDescription: nil); details.imagePosition = .imageLeading; details.setAccessibilityLabel(detailed ? "Hide project details" : "Show project details"); overview.addArrangedSubview(details)
        if detailed {
        if let raw = data["tokenUsage"] { if let u = usage(raw, scopes: ["project", "linked-chat"], defaultScope: "project") { let prefix = u.scope == "linked-chat" ? "Linked chat · " : "Estimated project tokens · "; let line = label(prefix + tokensText(u) + (u.scope == "linked-chat" ? " · Project total not measured" : ""), size: 11, color: muted); line.toolTip = tokenDetails(u) + " · Coverage: " + u.coverage; line.setAccessibilityHelp(line.toolTip); addFull(line, to: overview) } else { addFull(label("Project usage unavailable · invalid data", size: 11, color: .systemOrange), to: overview) } } else { addFull(label("Project usage · Not measured", size: 11, color: muted), to: overview) }
            let savedAt = (record["updatedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) == nil ? nil : $0 } ?? "Not recorded or invalid"
            addFull(detailRow("SAVED AT", savedAt), to: overview)
            addFull(detailGroups("SAVING SESSION ID", record["updatedBySession"] as? String ?? "Not recorded"), to: overview)
            if let closure = data["checkpointClosure"] as? [String: Any] {
                if let condition = closure["finishCondition"] as? String { addFull(detailGroups("FINISH CONDITION", condition), to: overview) }
                if let evidence = closure["evidence"] as? String, closure["state"] as? String == "complete" { addFull(detailGroups("COMPLETION EVIDENCE", evidence), to: overview) }
            }
            if let range = data["effortRange"] as? [String: Any], let min = strictInteger(range["min"]), let max = strictInteger(range["max"]), min <= max, let unit = range["unit"] as? String, let source = range["source"] as? String, let coverage = range["coverage"] as? String {
                addFull(detailRow("ACTIVE EFFORT", "\(min)–\(max) \(unit)"), to: overview)
                addFull(detailGroups("EFFORT SOURCE", source), to: overview)
                addFull(detailGroups("EFFORT COVERAGE", coverage), to: overview)
            }
            if let cycle = data["recurring"] as? [String: Any], let current = cycle["current"] as? String, let source = cycle["source"] as? String {
                addFull(detailGroups("CURRENT CYCLE", current), to: overview)
                addFull(detailGroups("LAST CYCLE", cycle["last"] as? String ?? "Not recorded"), to: overview)
                addFull(detailGroups("NEXT CYCLE", cycle["next"] as? String ?? "Not recorded"), to: overview)
                addFull(detailGroups("CYCLE SOURCE", source), to: overview)
            }
            if let wait = data["externalWait"] as? [String: Any], let reason = wait["reason"] as? String, let source = wait["source"] as? String {
                addFull(detailGroups("EXTERNAL WAIT", reason), to: overview)
                addFull(detailGroups("WAIT SOURCE", source), to: overview)
            }
            if let effort = data["effort"] as? String, !effort.isEmpty { addFull(detailGroups("EFFORT", effort), to: overview) }
            if let raw = data["tokenUsage"], let u = usage(raw, scopes: ["project", "linked-chat"], defaultScope: "project") { addFull(detailGroups("COVERAGE", u.coverage), to: overview); addFull(detailGroups("SOURCE", u.source), to: overview); if let asOf = u.asOf { addFull(detailRow("AS OF", asOf), to: overview) } }
        }
        if data["contextURL"] is String { let button = NSButton(title: "Open project context", target: self, action: #selector(contextClicked)); button.isBordered = false; button.contentTintColor = .systemBlue; overview.addArrangedSubview(button) }
        addFull(overview, to: body)
        let milestones = card()
        switch checklist(data) {
        case .missing: addFull(label("No milestones recorded", color: muted), to: milestones)
        case .invalid: addFull(label("Milestones unavailable · invalid data", color: .systemOrange), to: milestones)
        case .items(let items):
            if items.isEmpty { addFull(label("No milestones recorded", color: muted), to: milestones) }
            else { addFull(label("\(items.filter(\.done).count) of \(items.count) milestones complete", size: 11, weight: .semibold, color: muted), to: milestones); if detailed { addFull(label("Task tokens · Not measured unless shown", size: 10, color: muted), to: milestones) } }
            let defaults = defaultExpanded(items, current: data["currentMilestoneID"] as? String)
            let choices = UserDefaults.standard.dictionary(forKey: "glance.expansion." + id) as? [String: Bool] ?? [:]
            func addNode(_ item: Milestone, _ depth: Int) {
                let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.spacing = 6
                if depth > 0 { let indent = NSView(); indent.widthAnchor.constraint(equalToConstant: CGFloat(depth * 14)).isActive = true; indent.heightAnchor.constraint(equalToConstant: 1).isActive = true; row.addArrangedSubview(indent) }
                let isOpen = choices[item.id] ?? defaults.contains(item.id)
                if !item.children.isEmpty { let disclosure = NSButton(); disclosure.setButtonType(.toggle); disclosure.isBordered = false; disclosure.image = NSImage(systemSymbolName: isOpen ? "chevron.down" : "chevron.right", accessibilityDescription: nil); disclosure.target = self; disclosure.action = #selector(toggleBranch(_:)); disclosure.identifier = NSUserInterfaceItemIdentifier(item.id); disclosure.state = isOpen ? .on : .off; disclosure.setAccessibilityLabel((isOpen ? "Collapse " : "Expand ") + item.title); disclosure.widthAnchor.constraint(equalToConstant: 16).isActive = true; row.addArrangedSubview(disclosure) }
                else { let spacer = NSView(); spacer.widthAnchor.constraint(equalToConstant: 16).isActive = true; spacer.heightAnchor.constraint(equalToConstant: 1).isActive = true; row.addArrangedSubview(spacer) }
                let symbol = NSImageView(); symbol.image = NSImage(systemSymbolName: item.done ? "checkmark.square.fill" : "square", accessibilityDescription: nil); symbol.contentTintColor = item.done ? .systemBlue : muted; symbol.widthAnchor.constraint(equalToConstant: 16).isActive = true; symbol.heightAnchor.constraint(equalToConstant: 17).isActive = true; symbol.setAccessibilityElement(true); symbol.setAccessibilityRole(.checkBox); symbol.setAccessibilityLabel(item.title + ", read only"); symbol.setAccessibilityValue(item.done ? 1 : 0); row.addArrangedSubview(symbol)
                let texts = column(2); let isCurrent = (data["currentMilestoneID"] as? String) == item.id; let name = label(item.title + (isCurrent ? "  ·  Current" : ""), color: (item.done || isCurrent) ? .white : NSColor(white: 0.8, alpha: 1)); addFull(name, to: texts)
                if detailed, item.done, let u = item.tokens { let detail = label("Estimated task tokens · " + tokensText(u) + " · " + u.coverage + " · " + tokenDetails(u), size: 10, color: muted); detail.toolTip = tokenDetails(u) + " · Coverage: " + u.coverage; detail.setAccessibilityHelp(detail.toolTip); addFull(detail, to: texts) }
                if !item.children.isEmpty && !isOpen { addFull(label("\(item.children.filter(\.done).count) of \(item.children.count) substeps complete", size: 10, color: muted), to: texts) }
                row.addArrangedSubview(texts); texts.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -CGFloat((depth == 0 ? 44 : 50) + depth * 14)).isActive = true; addFull(row, to: milestones)
                if isOpen { for child in item.children { addNode(child, depth + 1) } }
            }
            for item in items { addNode(item, 0) }
        }
        addFull(milestones, to: body)
        let fresh = label(freshness(record), size: 11, color: muted); freshnessLabel = fresh; addFull(fresh, to: body)
        if let state = (data["health"] as? [String: Any])?["state"] as? String, state == "waiting-on-you" || state == "parked" {
            addFull(label("Saved health: \(state == "parked" ? "Parked" : "Waiting on you") · age above is time since save", size: 11, color: muted), to: body)
        }
        let saver: String
        if let session = record["updatedBySession"] as? String {
            if session.hasPrefix("codex-") { saver = "Codex session" }
            else if session.hasPrefix("claude-") { saver = "Claude session" }
            else { saver = "Unknown assistant" }
        } else { saver = "Not recorded" }
        addFull(label("Last saved by: " + saver, size: 11, color: muted), to: body)
        layoutSubtreeIfNeeded(); if preserve { scroll.contentView.scroll(to: previousOffset); scroll.reflectScrolledClipView(scroll.contentView) }

    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let root: URL = { let args = CommandLine.arguments; if let i = args.firstIndex(of: "--store"), i+1 < args.count { return URL(fileURLWithPath: args[i+1], isDirectory: true) }; return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ProjectOverview", isDirectory: true) }()
    let overview = Overview(); let popover = NSPopover(); var status: NSStatusItem!; var watcher: DispatchSourceFileSystemObject?; var timer: Timer?; var retry: Timer?
    var cached: [String: [String: Any]] = [:]; var hasSnapshot = false; var usingBackup = false; var selected = UserDefaults.standard.string(forKey: "selectedProject"); var unavailable = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory); let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item); let sub = NSMenu(); sub.addItem(withTitle: "Quit Glance", action: #selector(quit), keyEquivalent: "q"); item.submenu = sub; NSApp.mainMenu = menu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); status.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Glance"); status.button?.image?.isTemplate = true; status.button?.toolTip = "Glance"; status.button?.setAccessibilityLabel("Glance"); status.button?.target = self; status.button?.action = #selector(toggle)
        let controller = NSViewController(); controller.view = overview; popover.contentViewController = controller; popover.contentSize = overview.frame.size; popover.behavior = .transient; popover.delegate = self
        overview.onSelect = { [weak self] id in self?.selected = id; UserDefaults.standard.set(id, forKey: "selectedProject"); self?.redraw() }; overview.onQuit = { NSApp.terminate(nil) }; overview.onSettings = { [weak self] in self?.settings() }; overview.onCopyPrompt = { prompt in let pasteboard = NSPasteboard.general; pasteboard.clearContents(); pasteboard.setString(prompt, forType: .string) }; overview.onContext = { [weak self] in self?.openContext() }
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
    func redraw() { overview.recoveredBackup = usingBackup; overview.render(projects: cached, selected: selected, unavailable: unavailable) }
    func readValidated(_ url: URL) -> [String: [String: Any]]? {
        guard let bytes = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any], [1, 2].contains(strictInteger(obj["schema"]) ?? -1), let projects = obj["projects"] as? [String: [String: Any]] else { return nil }
        if strictInteger(obj["schema"]) == 2 { guard let generation = obj["generation"] as? String, UUID(uuidString: generation) != nil else { return nil } }
        var requests = Set<String>()
        func validID(_ v: String) -> Bool { v.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil }
        for (id, record) in projects {
            guard validID(id), record["id"] as? String == id, strictInteger(record["schema"]) == 1, let request = record["request"] as? String, validID(request), requests.insert(request).inserted, let version = strictInteger(record["version"]), version >= 1, let sessions = record["sessions"] as? [String], !sessions.isEmpty, Set(sessions).count == sessions.count, sessions.allSatisfy(validID), let status = record["status"] as? [String: Any] else { return nil }
            for key in ["goal", "checkpoint", "status"] { guard let value = status[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil } }
            if case .invalid = checklist(status) { return nil }
            guard validExtras(status) else { return nil }
            if status["health"] != nil && health(status) == nil { return nil }
            if let raw = record["updatedBySession"] { guard let updater = raw as? String, validID(updater), sessions.contains(updater) else { return nil } }
        }
        return projects
    }
    func refresh() {
        if let projects = readValidated(root.appendingPathComponent("store.json")) { cached = projects; hasSnapshot = true; usingBackup = false; unavailable = false; redraw(); return }
        if !hasSnapshot, let backup = readValidated(root.appendingPathComponent("store.backup.json")) { cached = backup; hasSnapshot = true; usingBackup = true }
        unavailable = true; redraw()
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
        let alert = NSAlert(); alert.messageText = "Glance settings"; alert.informativeText = "Store: \(root.path)\nVersion: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"; alert.addButton(withTitle: "Done"); alert.addButton(withTitle: "Reveal Store"); alert.addButton(withTitle: SMAppService.mainApp.status == .enabled ? "Turn Off Open at Login" : "Turn On Open at Login")
        let result = alert.runModal(); if result == .alertSecondButtonReturn { NSWorkspace.shared.activateFileViewerSelecting([root]) }; if result == .alertThirdButtonReturn { do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } } catch { let failure = NSAlert(error: error); failure.runModal() } }
    }
}

func preview(_ path: String) {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let payload: [String: Any] = ["name":"Atlas", "goal":"Keep the project visible through clear checkpoints.", "checkpoint":"Connect participating sessions", "status":"Review underway", "next":"Connect one assistant, then verify a saved update.", "effort":"Not yet calibrated", "tokenUsage":["estimate":240000, "scope":"linked-chat", "source":"Fictional example", "coverage":"Illustrative linked chat only"], "currentMilestoneID":"preview", "checklist": [
        ["id":"preview", "title":"Review the refined overview", "done":false, "children": [["id":"icon", "title":"Menu bar icon built", "done":true], ["id":"nested", "title":"Nested milestones built", "done":true], ["id":"usage", "title":"Token labels added", "done":true], ["id":"visual", "title":"Check the layout", "done":false]]],
        ["id":"scope", "title":"Agree scope", "done":true], ["id":"build", "title":"Build the first version", "done":true], ["id":"verify", "title":"Verify the core workflow", "done":true], ["id":"docs", "title":"Record the decisions", "done":true], ["id":"review", "title":"Complete local review", "done":true],
        ["id":"integration", "title":"Connect both assistants", "done":false, "children": [["id":"contract", "title":"Prepare shared contract", "done":true], ["id":"codex", "title":"Connect Codex", "done":false], ["id":"claude", "title":"Connect Claude", "done":false]]],
        ["id":"release", "title":"Check startup and displays", "done":false]]]

    let now = ISO8601DateFormatter().string(from: Date())
    let rec: [String: Any] = ["id":"demo", "status":payload, "updatedAt":now]
    func capture(_ name: String, _ projects: [String: [String: Any]], _ selected: String?, _ unavailable: Bool = false, bottom: Bool = false) {
        let previousDetails = UserDefaults.standard.object(forKey: "glance.details.demo")
        defer { if let previousDetails { UserDefaults.standard.set(previousDetails, forKey: "glance.details.demo") } else { UserDefaults.standard.removeObject(forKey: "glance.details.demo") } }
        let view = Overview(); let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false); window.title = "Glance fictional demo · visual self-test"; window.contentView = view
        view.render(projects: projects, selected: selected, unavailable: unavailable); if name == "help" { view.openHelp() }; if name == "all-projects" { view.showAllProjects() }; if name == "details" || name == "details-bottom" || name == "details-middle" { UserDefaults.standard.set(true, forKey: "glance.details.demo"); view.lastSignature = nil; view.render(projects: projects, selected: selected, unavailable: unavailable) }; view.layoutSubtreeIfNeeded()
        if bottom { let distance = view.body.frame.height - view.scroll.contentSize.height; guard distance > 0 else { fputs("Long fixture did not create scrollable content\n", stderr); exit(2) }; view.scroll.contentView.scroll(to: NSPoint(x: 0, y: distance)); view.scroll.reflectScrolledClipView(view.scroll.contentView) }
        if name == "details-middle" { let distance = max(0, view.body.frame.height - view.scroll.contentSize.height); view.scroll.contentView.scroll(to: NSPoint(x: 0, y: distance * 0.45)); view.scroll.reflectScrolledClipView(view.scroll.contentView) }
        window.orderFront(nil); window.display(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25)); view.displayIfNeeded()
        for scale in [1,2] { let rect = view.bounds; guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(rect.width)*scale, pixelsHigh: Int(rect.height)*scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }; rep.size = rect.size
            view.cacheDisplay(in: rect, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: "\(path)/\(name)-\(scale)x.png")) } }
        window.orderOut(nil)
    }
    let caseName = CommandLine.arguments.firstIndex(of: "--case").flatMap { $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1] : nil }
    if caseName == nil || caseName == "overview" { capture("overview", ["demo":rec], "demo") }
    var healthPayload = payload; healthPayload["health"] = ["state":"waiting-on-you", "reason":"Review the proposed scope before work continues."]
    if caseName == nil || caseName == "health" { capture("health", ["demo":["id":"demo", "status":healthPayload, "updatedAt":now, "updatedBySession":"codex-example"]], "demo") }
    var second = healthPayload; second["name"] = "Fictional second project"; second["checkpoint"] = "Await a review decision"
    if caseName == nil || caseName == "all-projects" { capture("all-projects", ["demo":rec, "second":["id":"second", "status":second, "updatedAt":now]], "demo") }
    healthPayload["checkpointClosure"] = ["state":"complete", "finishCondition":"Review passes", "evidence":"Reviewer recorded a pass"]
    healthPayload["effortRange"] = ["min":2, "max":4, "unit":"hours", "source":"Example estimate", "coverage":"This checkpoint"]
    healthPayload["externalWait"] = ["reason":"Waiting for review", "source":"Example request"]
    healthPayload["recurring"] = ["current":"November", "last":"October complete", "next":"December", "source":"Example schedule"]
    if caseName == nil || caseName == "details" { capture("details", ["demo":["id":"demo", "status":healthPayload, "updatedAt":now, "updatedBySession":"codex-example"]], "demo") }
    if caseName == nil || caseName == "details-middle" { capture("details-middle", ["demo":["id":"demo", "status":healthPayload, "updatedAt":now, "updatedBySession":"codex-example"]], "demo") }
    if caseName == nil || caseName == "details-bottom" { capture("details-bottom", ["demo":["id":"demo", "status":healthPayload, "updatedAt":now, "updatedBySession":"codex-example"]], "demo", bottom: true) }
    var legacy = payload; legacy.removeValue(forKey: "checklist"); legacy.removeValue(forKey: "currentMilestoneID"); if caseName == nil || caseName == "legacy" { capture("legacy", ["demo":["id":"demo", "status":legacy, "updatedAt":now]], "demo") }
    if caseName == nil || caseName == "empty" { capture("empty", [:], nil) }
    if caseName == "help" { capture("help", [:], nil) }
    var invalid = payload; invalid["checklist"] = [["id":"broken", "title":"Unknown", "done":1]]; if caseName == nil || caseName == "invalid" { capture("invalid", ["demo":["id":"demo", "status":invalid, "updatedAt":now]], "demo") }
    var long = payload; long["goal"] = String(repeating:"A longer fictional goal for testing wrapping. ", count: 8); long.removeValue(forKey: "currentMilestoneID"); long["checklist"] = (1...12).map { ["id":"item-\($0)", "title":"Milestone \($0) with a longer description for scrolling", "done":false] as [String : Any] }; if caseName == nil || caseName == "long" { capture("long", ["demo":["id":"demo", "status":long, "updatedAt":now]], "demo") }; if caseName == nil || caseName == "long-bottom" { capture("long-bottom", ["demo":["id":"demo", "status":long, "updatedAt":now]], "demo", bottom: true) }
}
if let i = CommandLine.arguments.firstIndex(of: "--preview"), i+1 < CommandLine.arguments.count { preview(CommandLine.arguments[i+1]) } else { let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run() }
