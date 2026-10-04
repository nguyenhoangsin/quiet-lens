import Foundation
import Testing
@testable import QuietLens

struct APIKeyManagerTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("QuietLensKeyTests-\(UUID())", isDirectory: true)
    }

    @Test func savingReplacesOneFileAndRestoresAfterRelaunch() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = APIKeyManager(directory: directory)
        #expect(try manager.read() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        try manager.save("  fake-first-key\n")
        #expect(try APIKeyManager(directory: directory).read() == "fake-first-key")
        for number in 0..<10 { try manager.save("fake-replacement-\(number)") }
        #expect(try APIKeyManager(directory: directory).read() == "fake-replacement-9")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["APIKey.json"])
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: manager.fileURL.path)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
    }

    @Test func removeClearsSavedKeyAndEmptyDirectoryWithoutCreatingAnything() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = APIKeyManager(directory: directory)
        try manager.delete()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        try manager.save("fake-key")
        try manager.delete()
        #expect(try manager.read() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        try manager.delete()
    }

    @Test func removePreservesOtherAppData() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = APIKeyManager(directory: directory)
        try manager.save("fake-key")
        let otherFile = directory.appendingPathComponent("OtherData.txt")
        try Data("keep".utf8).write(to: otherFile)
        try manager.delete()
        #expect(!FileManager.default.fileExists(atPath: manager.fileURL.path))
        #expect(try String(contentsOf: otherFile, encoding: .utf8) == "keep")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["OtherData.txt"])
    }

    @Test func invalidSavePreservesExistingKey() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = APIKeyManager(directory: directory)
        try manager.save("fake-key")
        #expect(throws: (any Error).self) { try manager.save("  \n") }
        #expect(try manager.read() == "fake-key")
    }
}
