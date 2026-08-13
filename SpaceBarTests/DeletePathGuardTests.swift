import XCTest
@testable import SpaceBar

/// The guard is the last thing standing between a stale row and somebody's source tree, so it is
/// tested against the paths a bug would most plausibly hand it.
final class DeletePathGuardTests: XCTestCase {
    private var home: URL!
    private var project: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        home = FileManager.default.homeDirectoryForCurrentUser
        project = home.appendingPathComponent(
            "DeletePathGuardTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: project)
        try super.tearDownWithError()
    }

    func testAcceptsAnArtifactFolderInsideAProject() throws {
        let artifact = try makeFolder("node_modules")

        XCTAssertNoThrow(try DeletePathGuard.validateForBuildArtifactDelete(artifact))
    }

    func testRefusesAFolderNoRuleWouldHaveMatched() throws {
        let source = try makeFolder("src")

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(source))
    }

    func testRefusesAnArtifactNameSittingStraightInHome() {
        let url = home.appendingPathComponent("node_modules", isDirectory: true)

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(url))
    }

    func testRefusesPathsUnderLibrary() {
        let url = home.appendingPathComponent("Library/Caches/node_modules", isDirectory: true)

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(url))
    }

    func testRefusesPathsOutsideHome() {
        let url = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules", isDirectory: true)

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(url))
    }

    func testRefusesAFileWearingAnArtifactName() throws {
        let file = project.appendingPathComponent("node_modules")
        try Data("not a folder".utf8).write(to: file)

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(file))
    }

    func testRefusesASymlinkPointingAtSomethingElse() throws {
        let real = try makeFolder("keep-me")
        let link = project.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        XCTAssertThrowsError(try DeletePathGuard.validateForBuildArtifactDelete(link))
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = project.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
