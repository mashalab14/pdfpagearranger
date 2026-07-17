import XCTest

final class HookScriptsRegressionTests: XCTestCase {
    func testPreCommitRunsFastBuildNotFullRegressionByDefault() throws {
        let source = try hookScript(named: "pre-commit")
        XCTAssertTrue(source.contains("build"))
        XCTAssertTrue(source.contains("RUN_FULL_REGRESSION"))
        XCTAssertTrue(source.contains("run-full-regression.sh"))
        XCTAssertTrue(source.contains("PRE_COMMIT_ONLY_TESTING"))
        XCTAssertFalse(source.contains("pre-commit: running PDF Pages regression tests"))
        XCTAssertFalse(source.contains("-destination \"$DESTINATION\" \\\n  test"))
    }

    func testFullRegressionScriptRunsCompleteSuite() throws {
        let source = try hookScript(named: "run-full-regression.sh")
        XCTAssertTrue(source.contains("run-full-regression: running complete PDF Pages regression suite"))
        XCTAssertTrue(source.contains("test"))
        XCTAssertTrue(source.contains("resolve_destination") || source.contains("DESTINATION"))
        XCTAssertTrue(source.contains("REGRESSION_DESTINATION") || source.contains("iPhone 17"))
        XCTAssertFalse(source.contains("PRE_COMMIT_ONLY_TESTING"))
        XCTAssertFalse(source.contains("-only-testing:"))
    }

    private func hookScript(named fileName: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent("scripts").appendingPathComponent(fileName),
            encoding: .utf8
        )
    }
}
