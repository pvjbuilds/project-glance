import Foundation
import Darwin
import CoreFoundation

struct StoreError: Error, CustomStringConvertible { let description: String; init(_ s: String) { description = s } }
let fm = FileManager.default
func fail(_ s: String) -> Never { fputs("\(s)\n", stderr); exit(1) }
func valid(_ s: String) -> Bool { !s.isEmpty && s.count <= 80 && s.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil }
func readObject(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw StoreError("Invalid JSON object: \(url.lastPathComponent)") }; return o
}
func save(_ object: [String: Any], _ url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}
func text(_ o: [String: Any], _ key: String) throws -> String {
    guard let value = o[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError("Missing field: \(key)") }; return value
}
func validateChecklist(_ payload: [String: Any]) throws {
    guard let raw = payload["checklist"] else { return }
    guard let items = raw as? [[String: Any]] else { throw StoreError("Invalid checklist: expected an array") }
    var ids = Set<String>()
    for item in items {
        guard let id = item["id"] as? String, valid(id), ids.insert(id).inserted,
              let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let done = item["done"] as? NSNumber, CFGetTypeID(done) == CFBooleanGetTypeID() else { throw StoreError("Invalid checklist item") }
    }
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
    else if !fm.fileExists(atPath: root.appendingPathComponent("store.json").path) { throw StoreError("Store does not exist: \(root.path)") }
    let lockPath = root.appendingPathComponent(".lock").path
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o600); guard fd >= 0 else { throw StoreError("Cannot open lock") }; defer { close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw StoreError("Cannot lock store") }; defer { flock(fd, LOCK_UN) }
    let storeURL = root.appendingPathComponent("store.json")
    var store: [String: Any] = fm.fileExists(atPath: storeURL.path) ? try readObject(storeURL) : ["schema": 1, "projects": [:]]
    guard store["schema"] as? Int == 1, var projects = store["projects"] as? [String: [String: Any]] else { throw StoreError("Invalid store") }
    if command == "list" { print(String(data: try JSONSerialization.data(withJSONObject: store, options: [.sortedKeys]), encoding: .utf8)!); return }
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
        projects[id] = ["schema": 1, "id": id, "request": request, "version": 1, "sessions": [session], "updatedAt": ISO8601DateFormatter().string(from: Date()), "status": payload]
        try commit(); print("enrolled: \(id)"); return
    }
    guard var record = projects[id] else { throw StoreError("Project not enrolled") }
    guard record["schema"] as? Int == 1, record["id"] as? String == id, let version = record["version"] as? Int, var sessions = record["sessions"] as? [String] else { throw StoreError("Invalid project record") }
    if command == "connect" {
        guard args.count == 4, valid(args[3]) else { throw StoreError("Usage: connect ID SESSION") }
        if !sessions.contains(args[3]) { sessions.append(args[3]); record["sessions"] = sessions; record["version"] = version + 1; projects[id] = record; try commit() }
        print("connected: \(id)"); return
    }
    if command == "update" {
        guard args.count == 6, valid(args[3]), let expected = Int(args[4]) else { throw StoreError("Usage: update ID SESSION VERSION JSON") }
        guard sessions.contains(args[3]) else { throw StoreError("Session is not associated") }
        guard expected == version else { throw StoreError("Version conflict: current version is \(version)") }
        let payload = try readObject(URL(fileURLWithPath: args[5]))
        _ = try text(payload, "goal"); _ = try text(payload, "checkpoint"); _ = try text(payload, "status"); try validateChecklist(payload)
        record["status"] = payload; record["version"] = version + 1; record["updatedAt"] = ISO8601DateFormatter().string(from: Date()); projects[id] = record; try commit(); print("updated: \(id) version \(version + 1)"); return
    }

    throw StoreError("Unknown command")
}
do { try run() } catch { fail("Error: \(error)") }
