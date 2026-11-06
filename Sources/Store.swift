import Foundation
import Darwin
import CoreFoundation
import CryptoKit

// JSON integers only; reject booleans, floating-point encodings and unsafe versions.
func strictInteger(_ raw: Any?, max: Int = 9_007_199_254_740_990) -> Int? {
    guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
          ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"].contains(String(cString: n.objCType)),
          let value = n as? Int, value >= 0, value <= max else { return nil }
    return value
}

struct StoreError: Error, CustomStringConvertible { let description: String; init(_ s: String) { description = s } }
let fm = FileManager.default
func fail(_ s: String) -> Never { fputs("\(s)\n", stderr); exit(1) }
func valid(_ s: String) -> Bool { !s.isEmpty && s.count <= 80 && s.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil }
func readObject(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw StoreError("Invalid JSON object: \(url.lastPathComponent)") }; return o
}
// Each replacement is durable before the next step. This is not a transaction
// across the backup and primary: a failed primary write may advance the backup.
func durableReplace(_ data: Data, _ url: URL) throws {
    let dir = url.deletingLastPathComponent()
    var name = Array(dir.appendingPathComponent(".glance-XXXXXX").path.utf8CString)
    let fd = mkstemp(&name)
    guard fd >= 0 else { throw StoreError("Cannot create temporary store: errno \(errno)") }
    let temp = String(cString: name)
    defer { close(fd); unlink(temp) }
    guard fchmod(fd, 0o600) == 0 else { throw StoreError("Cannot protect temporary store: errno \(errno)") }
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let n = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if n < 0 && errno == EINTR { continue }
            guard n > 0 else { throw StoreError("Cannot write temporary store: errno \(errno)") }
            offset += n
        }
    }
    guard fsync(fd) == 0 else { throw StoreError("Cannot sync temporary store: errno \(errno)") }
    guard rename(temp, url.path) == 0 else { throw StoreError("Cannot replace store: errno \(errno)") }
    let dfd = open(dir.path, O_RDONLY)
    guard dfd >= 0 else { throw StoreError("Cannot open store directory for sync: errno \(errno)") }
    defer { close(dfd) }
    guard fsync(dfd) == 0 else { throw StoreError("Cannot sync store directory: errno \(errno)") }
}
func validateStore(_ store: [String: Any]) throws {
    guard let schema = strictInteger(store["schema"]), [1, 2].contains(schema), let projects = store["projects"] as? [String: [String: Any]] else { throw StoreError("Invalid store envelope") }
    if schema == 2 { guard let generation = store["generation"] as? String, UUID(uuidString: generation) != nil else { throw StoreError("Invalid store generation") } }
    var requests = Set<String>()
    for (id, record) in projects {
        guard valid(id), record["id"] as? String == id, strictInteger(record["schema"]) == 1,
              let request = record["request"] as? String, valid(request), requests.insert(request).inserted,
              let version = strictInteger(record["version"]), version >= 1,
              let sessions = record["sessions"] as? [String], !sessions.isEmpty, Set(sessions).count == sessions.count, sessions.allSatisfy(valid),
              let status = record["status"] as? [String: Any] else { throw StoreError("Invalid project record: \(id)") }
        _ = try text(status, "goal"); _ = try text(status, "checkpoint"); _ = try text(status, "status"); try validateChecklist(status)
        if let updater = record["updatedBySession"] { guard let updater = updater as? String, valid(updater), sessions.contains(updater) else { throw StoreError("Invalid updater session: \(id)") } }
    }
}
func save(_ object: [String: Any], _ url: URL) throws {
    try validateStore(object)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    // Preserve the exact validated predecessor, never an invalid primary.
    if fm.fileExists(atPath: url.path) {
        let prior = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: prior) as? [String: Any] else { throw StoreError("Invalid existing store") }
        try validateStore(obj)
        try durableReplace(prior, url.deletingLastPathComponent().appendingPathComponent("store.backup.json"))
    }
    try durableReplace(data, url)
}
func text(_ o: [String: Any], _ key: String) throws -> String {
    guard let value = o[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError("Missing field: \(key)") }; return value
}
func validateUsage(_ raw: Any, scopes: Set<String>) throws {
    guard let u = raw as? [String: Any], let n = u["estimate"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue <= 9_007_199_254_740_991, n.doubleValue.rounded(.towardZero) == n.doubleValue else { throw StoreError("Invalid token estimate") }
    guard try text(u, "source").count <= 2000, try text(u, "coverage").count <= 2000 else { throw StoreError("Usage metadata too long") }
    if let scope = u["scope"] { guard let v = scope as? String, scopes.contains(v) else { throw StoreError("Invalid usage scope") } }
    if let asOf = u["asOf"] { guard let v = asOf as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError("Invalid usage date") } }
}
func validateHealth(_ payload: [String: Any]) throws {
    guard let raw = payload["health"] else { return }
    guard let health = raw as? [String: Any], let state = health["state"] as? String,
          ["moving", "waiting-on-you", "blocked", "parked", "needs-scoping", "checkpoint-complete"].contains(state),
          let reason = health["reason"] as? String, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reason.count <= 2000 else { throw StoreError("Invalid health: supply a supported state and nonempty reason (up to 2000 characters)") }
}
func validateExtras(_ payload: [String: Any]) throws {
    if let raw = payload["externalWait"] {
        guard let v = raw as? [String: Any] else { throw StoreError("Invalid external wait") }
        for key in ["reason", "source"] { guard let value = v[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 2000 else { throw StoreError("External wait needs reason and source") } }
    }
    if let raw = payload["recurring"] {
        guard let v = raw as? [String: Any] else { throw StoreError("Invalid recurring cycle") }
        for key in ["current", "source"] { guard let value = v[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 2000 else { throw StoreError("Recurring cycle needs current and source") } }
        for key in ["last", "next"] { if let value = v[key] { guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 2000 else { throw StoreError("Invalid recurring cycle field") } } }
    }
    if let raw = payload["effortRange"] {
        guard let v = raw as? [String: Any], let min = strictInteger(v["min"]), let max = strictInteger(v["max"]), min <= max,
              let unit = v["unit"] as? String, ["minutes", "hours", "days"].contains(unit),
              let source = v["source"] as? String, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let coverage = v["coverage"] as? String, !coverage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, source.count <= 2000, coverage.count <= 2000 else { throw StoreError("Invalid effort range") }
    }
    if let raw = payload["checkpointClosure"] {
        guard let value = raw as? [String: Any], let state = value["state"] as? String, ["open", "complete"].contains(state), let condition = value["finishCondition"] as? String, !condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, condition.count <= 2000 else { throw StoreError("Invalid checkpoint closure") }
        if state == "complete" { guard let evidence = value["evidence"] as? String, !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, evidence.count <= 2000 else { throw StoreError("Completed checkpoint needs evidence") } }
        if let evidence = value["evidence"] { guard let evidence = evidence as? String, evidence.count <= 2000 else { throw StoreError("Invalid checkpoint evidence") } }
    }
}
func validateChecklist(_ payload: [String: Any]) throws {
    try validateExtras(payload)
    try validateHealth(payload)
    if let usage = payload["tokenUsage"] { try validateUsage(usage, scopes: ["project", "linked-chat"]) }
    guard let raw = payload["checklist"] else { if payload["currentMilestoneID"] != nil { throw StoreError("Current milestone requires a checklist") }; return }
    guard let items = raw as? [[String: Any]] else { throw StoreError("Invalid checklist: expected an array") }
    var ids = Set<String>(), pending = Set<String>(), count = 0
    func visit(_ nodes: [[String: Any]], _ depth: Int) throws {
        guard depth <= 4 else { throw StoreError("Checklist is too deeply nested") }
        for item in nodes {
            count += 1; guard count <= 200 else { throw StoreError("Checklist has too many items") }
            guard let id = item["id"] as? String, valid(id), ids.insert(id).inserted,
                  let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let done = item["done"] as? NSNumber, CFGetTypeID(done) == CFBooleanGetTypeID() else { throw StoreError("Invalid checklist item") }
            if !done.boolValue { pending.insert(id) }
            if let usage = item["tokenUsage"] { try validateUsage(usage, scopes: ["task"]) }
            if let rawChildren = item["children"] { guard let children = rawChildren as? [[String: Any]] else { throw StoreError("Invalid checklist children") }; if done.boolValue && children.contains(where: { ($0["done"] as? NSNumber)?.boolValue == false }) { throw StoreError("Completed item has pending child") }; if !children.isEmpty { try visit(children, depth + 1) } }
        }
    }
    try visit(items, 1)
    if let current = payload["currentMilestoneID"] { guard let id = current as? String, pending.contains(id) else { throw StoreError("Current milestone must identify a pending item") } }
}

func run() throws {
    var args = Array(CommandLine.arguments.dropFirst())
    var root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ProjectOverview", isDirectory: true)
    if args.first == "--store" {
        guard args.count >= 3 else { throw StoreError("Usage: glance-store [--store DIRECTORY] COMMAND ...") }
        root = URL(fileURLWithPath: args[1], isDirectory: true); args.removeFirst(2)
    }
    args.insert(root.path, at: 0)
    guard args.count >= 2 else { throw StoreError("Usage: glance-store [--store DIRECTORY] list | enroll ID REQUEST SESSION JSON | connect ID SESSION | update ID SESSION VERSION JSON") }
    let command = args[1]
    if command == "enroll" { try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
    else if command != "recover" && !fm.fileExists(atPath: root.appendingPathComponent("store.json").path) { throw StoreError("Store does not exist: \(root.path)") }
    let lockPath = root.appendingPathComponent(".lock").path
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o600); guard fd >= 0 else { throw StoreError("Cannot open lock") }; defer { close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw StoreError("Cannot lock store") }; defer { flock(fd, LOCK_UN) }
    let storeURL = root.appendingPathComponent("store.json")
    if command == "recover" {
        guard args.count == 5, args[4] == "accept-data-loss" else { throw StoreError("Usage: recover BACKUP_SHA256 PRIMARY_SHA256_OR_missing accept-data-loss") }
        let backupURL = root.appendingPathComponent("store.backup.json")
        let backupData = try Data(contentsOf: backupURL)
        let digest: (Data) -> String = { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
        guard digest(backupData) == args[2], let backup = try JSONSerialization.jsonObject(with: backupData) as? [String: Any] else { throw StoreError("Backup changed or invalid") }
        try validateStore(backup)
        let primaryData = fm.fileExists(atPath: storeURL.path) ? try Data(contentsOf: storeURL) : nil
        guard primaryData.map(digest) ?? "missing" == args[3] else { throw StoreError("Primary changed; inspect again") }
        if let primaryData {
            if let object = try? JSONSerialization.jsonObject(with: primaryData) as? [String: Any], (try? validateStore(object)) != nil { throw StoreError("Primary is valid; recovery refused") }
            let archive = root.appendingPathComponent("store.corrupt." + UUID().uuidString + ".json")
            try durableReplace(primaryData, archive)
            print("preserved corrupt primary: \(archive.path)")
        }
        var restored = backup; restored["schema"] = 2; restored["generation"] = UUID().uuidString
        try validateStore(restored)
        let bytes = try JSONSerialization.data(withJSONObject: restored, options: [.prettyPrinted, .sortedKeys])
        try durableReplace(bytes, storeURL)
        print("recovered backup \(args[2]); generation \(restored["generation"]!); later changes may be lost; list to verify")
        return
    }
    if !fm.fileExists(atPath: storeURL.path) && fm.fileExists(atPath: root.appendingPathComponent("store.backup.json").path) { throw StoreError("Primary store missing; backup exists. Explicit recovery required") }
    var store: [String: Any] = fm.fileExists(atPath: storeURL.path) ? try readObject(storeURL) : ["schema": 1, "projects": [:]]
    try validateStore(store)
    guard let schema = strictInteger(store["schema"]), [1, 2].contains(schema), var projects = store["projects"] as? [String: [String: Any]] else { throw StoreError("Invalid store") }
    if command == "list" {
        var result = store
        if schema == 2, let generation = store["generation"] as? String {
            var listed = projects
            for (id, var record) in listed { record["updateToken"] = generation + ":" + String(strictInteger(record["version"])!); listed[id] = record }
            result["projects"] = listed
        }
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!); return
    }
    if command == "migrate" {
        guard args.count == 2, schema == 1 else { throw StoreError("Migration requires a schema-1 store") }
        store["schema"] = 2; store["generation"] = UUID().uuidString; try save(store, storeURL); print("migrated: generation-aware updates enabled; list for tokens"); return
    }
    guard args.count >= 3, valid(args[2]) else { throw StoreError("Invalid project ID") }
    let id = args[2]
    func commit() throws { store["projects"] = projects; try save(store, storeURL) }
    if command == "enroll" {
        guard args.count == 6, valid(args[3]), valid(args[4]) else { throw StoreError("Usage: enroll ID REQUEST SESSION JSON") }
        let request = args[3], session = args[4]
        if let existing = projects[id] {
            guard existing["request"] as? String == request else { throw StoreError("Project ID already exists") }
            print("already enrolled: \(id)"); return
        }
        guard !projects.values.contains(where: { $0["request"] as? String == request }) else { throw StoreError("Request ID already belongs to another project") }
        let payload = try readObject(URL(fileURLWithPath: args[5]))
        _ = try text(payload, "goal"); _ = try text(payload, "checkpoint"); _ = try text(payload, "status"); try validateChecklist(payload)
        projects[id] = ["schema": 1, "id": id, "request": request, "version": 1, "sessions": [session], "updatedAt": ISO8601DateFormatter().string(from: Date()), "updatedBySession": session, "status": payload]
        try commit(); print("enrolled: \(id)"); return
    }
    guard var record = projects[id] else { throw StoreError("Project not enrolled") }
    guard strictInteger(record["schema"]) == 1, record["id"] as? String == id, let version = strictInteger(record["version"]), var sessions = record["sessions"] as? [String] else { throw StoreError("Invalid project record") }
    if command == "connect" {
        guard args.count == 4, valid(args[3]) else { throw StoreError("Usage: connect ID SESSION") }
        if !sessions.contains(args[3]) { sessions.append(args[3]); record["sessions"] = sessions; record["version"] = version + 1; projects[id] = record; try commit() }
        print("connected: \(id)"); return
    }
    if command == "update" {
        guard args.count == 6, valid(args[3]) else { throw StoreError("Usage: update ID SESSION VERSION JSON") }
        guard sessions.contains(args[3]) else { throw StoreError("Session is not associated; explicitly connect it before updating") }
        let expectedToken = schema == 2 ? (store["generation"] as! String) + ":" + String(version) : String(version)
        guard args[4] == expectedToken else { throw StoreError("Version conflict: list and reconcile before retrying") }
        let payload = try readObject(URL(fileURLWithPath: args[5]))
        _ = try text(payload, "goal"); _ = try text(payload, "checkpoint"); _ = try text(payload, "status"); try validateChecklist(payload)
        record["status"] = payload; record["version"] = version + 1; record["updatedBySession"] = args[3]; record["updatedAt"] = ISO8601DateFormatter().string(from: Date()); projects[id] = record; try commit(); print("updated: \(id) version \(version + 1)"); return
    }

    throw StoreError("Unknown command")
}
do { try run() } catch { fail("Error: \(error). If a write was attempted, list and inspect saved state before retrying; its outcome may be uncertain.") }
