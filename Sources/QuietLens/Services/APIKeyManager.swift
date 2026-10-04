import Foundation

protocol APIKeyManaging {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}

struct APIKeyManager: APIKeyManaging {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("APIKey.json") }
    private let files = FileManager.default

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/QuietLens", isDirectory: true)
    }

    func read() throws -> String? {
        guard files.fileExists(atPath: fileURL.path) else { return nil }
        let stored = try JSONDecoder().decode(StoredKey.self, from: Data(contentsOf: fileURL))
        guard !stored.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LensError.keyStorage }
        return stored.apiKey
    }

    func save(_ key: String) throws {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw LensError.keyRequired }
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        // Atomic replacement at one stable location; no dated copies or backup files.
        try JSONEncoder().encode(StoredKey(apiKey: value)).write(to: fileURL, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func delete() throws {
        if files.fileExists(atPath: fileURL.path) { try files.removeItem(at: fileURL) }
        // Leave other app data alone, but remove our directory when it is empty.
        if files.fileExists(atPath: directory.path),
           try files.contentsOfDirectory(atPath: directory.path).isEmpty {
            try files.removeItem(at: directory)
        }
    }

    private struct StoredKey: Codable { let apiKey: String }
}
