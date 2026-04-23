import XCTest
@testable import Typeflux

@MainActor
final class BundledModelAutoSetupTests: XCTestCase {
    func testApplyIfNeededInvokesLinkerAndSwallowsErrors() {
        let throwingLinker = StubBundledSenseVoiceLinker(result: .failure(
            NSError(domain: "BundledModelAutoSetupTests", code: 1),
        ))
        let setup = BundledModelAutoSetup(linker: throwingLinker)

        setup.applyIfNeeded()

        XCTAssertEqual(throwingLinker.invocationCount, 1)
    }

    func testApplyIfNeededReportsNoBundleWhenLinkerReturnsFalse() {
        let linker = StubBundledSenseVoiceLinker(result: .success(false))
        let setup = BundledModelAutoSetup(linker: linker)

        setup.applyIfNeeded()

        XCTAssertEqual(linker.invocationCount, 1)
    }

    func testApplyIfNeededReportsFullInstallWhenLinkerReturnsTrue() {
        let linker = StubBundledSenseVoiceLinker(result: .success(true))
        let setup = BundledModelAutoSetup(linker: linker)

        setup.applyIfNeeded()

        XCTAssertEqual(linker.invocationCount, 1)
    }

    func testEnsureBundledSenseVoiceLinked_withoutBundle_returnsFalse() throws {
        let emptyBundleRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("typeflux-bundle-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyBundleRoot, withIntermediateDirectories: true)

        let manager = LocalModelManager(
            fileManager: .default,
            sherpaOnnxInstaller: NoopSherpaOnnxInstaller(),
            applicationSupportURL: makeTempApplicationSupportURL(),
            bundledModelsRootURL: emptyBundleRoot,
        )

        let result = try manager.ensureBundledSenseVoiceLinked()

        XCTAssertFalse(result)
    }

    func testEnsureBundledSenseVoiceLinked_withValidBundle_createsSymlinkAndRecord() throws {
        let (manager, bundledStorageURL, appSupportURL) = try makeBundledSenseVoiceEnvironment()

        let result = try manager.ensureBundledSenseVoiceLinked()

        XCTAssertTrue(result)

        let configuration = LocalSTTConfiguration(
            model: .senseVoiceSmall,
            modelIdentifier: LocalSTTModel.senseVoiceSmall.defaultModelIdentifier,
            downloadSource: .huggingFace,
            autoSetup: true,
        )
        let targetPath = manager.storagePath(for: configuration)
        XCTAssertTrue(targetPath.hasPrefix(appSupportURL.path))

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: targetPath)
        XCTAssertEqual(destination, bundledStorageURL.path)

        let recordURL = URL(fileURLWithPath: targetPath, isDirectory: true)
            .deletingLastPathComponent()
            .appendingPathComponent("prepared.json", isDirectory: false)
        let recordData = try Data(contentsOf: recordURL)
        let recordJSON = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: recordData) as? [String: Any],
        )
        XCTAssertEqual(recordJSON["source"] as? String, LocalModelManager.bundledPreparedSource)
        XCTAssertEqual(recordJSON["modelIdentifier"] as? String, configuration.modelIdentifier)
    }

    func testEnsureBundledSenseVoiceLinked_isIdempotent() throws {
        let (manager, bundledStorageURL, _) = try makeBundledSenseVoiceEnvironment()

        let first = try manager.ensureBundledSenseVoiceLinked()
        let second = try manager.ensureBundledSenseVoiceLinked()

        XCTAssertTrue(first)
        XCTAssertTrue(second)

        let configuration = LocalSTTConfiguration(
            model: .senseVoiceSmall,
            modelIdentifier: LocalSTTModel.senseVoiceSmall.defaultModelIdentifier,
            downloadSource: .huggingFace,
            autoSetup: true,
        )
        let targetPath = manager.storagePath(for: configuration)
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: targetPath)
        XCTAssertEqual(destination, bundledStorageURL.path)
    }

    // MARK: - Fixtures

    private func makeBundledSenseVoiceEnvironment() throws -> (
        manager: LocalModelManager,
        bundledStorageURL: URL,
        applicationSupportURL: URL
    ) {
        let bundledModelsRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("typeflux-bundled-setup-\(UUID().uuidString)", isDirectory: true)
        let bundledStorageURL = bundledModelsRootURL
            .appendingPathComponent("senseVoiceSmall", isDirectory: true)
            .appendingPathComponent(LocalSTTModel.senseVoiceSmall.defaultModelIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundledStorageURL,
            withIntermediateDirectories: true,
        )
        try writeSenseVoiceFixture(into: bundledStorageURL)

        let appSupportURL = makeTempApplicationSupportURL()
        let manager = LocalModelManager(
            fileManager: .default,
            sherpaOnnxInstaller: NoopSherpaOnnxInstaller(),
            applicationSupportURL: appSupportURL,
            bundledModelsRootURL: bundledModelsRootURL,
        )
        return (manager, bundledStorageURL, appSupportURL)
    }

    private func writeSenseVoiceFixture(into storageURL: URL) throws {
        let layout = try XCTUnwrap(SherpaOnnxModelLayout.layout(for: .senseVoiceSmall))

        let runtimeBinURL = storageURL
            .appendingPathComponent(layout.runtimeRootDirectory, isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
        let runtimeLibURL = storageURL
            .appendingPathComponent(layout.runtimeRootDirectory, isDirectory: true)
            .appendingPathComponent("lib", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeBinURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtimeLibURL, withIntermediateDirectories: true)

        let machOMagic = Data([0xCF, 0xFA, 0xED, 0xFE, 0x46, 0x49, 0x58, 0x54, 0x55, 0x52, 0x45])

        let executableURL = runtimeBinURL.appendingPathComponent("sherpa-onnx-offline", isDirectory: false)
        try machOMagic.write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executableURL.path,
        )
        try machOMagic.write(to: runtimeLibURL.appendingPathComponent("libsherpa-onnx-c-api.dylib"))
        try machOMagic.write(to: runtimeLibURL.appendingPathComponent("libonnxruntime.dylib"))

        let modelDirectory = storageURL.appendingPathComponent(layout.modelRootDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data(repeating: 0x5A, count: 1_048_576)
            .write(to: modelDirectory.appendingPathComponent("model.int8.onnx"))
        try Data(
            """
            <unk> 0
            <s> 1
            </s> 2
            ▁the 3
            """.utf8,
        ).write(to: modelDirectory.appendingPathComponent("tokens.txt"))
    }

    private func makeTempApplicationSupportURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("typeflux-bundle-setup-app-support-\(UUID().uuidString)", isDirectory: true)
    }
}

private final class StubBundledSenseVoiceLinker: BundledSenseVoiceLinking {
    private let result: Result<Bool, Error>
    private(set) var invocationCount = 0

    init(result: Result<Bool, Error>) {
        self.result = result
    }

    @discardableResult
    func ensureBundledSenseVoiceLinked() throws -> Bool {
        invocationCount += 1
        return try result.get()
    }
}

private final class NoopSherpaOnnxInstaller: SherpaOnnxModelInstalling {
    func prepareModel(
        _ model: LocalSTTModel,
        at storageURL: URL,
        downloadSource: ModelDownloadSource,
        onUpdate: (@Sendable (LocalSTTPreparationUpdate) -> Void)?,
    ) async throws -> String {
        storageURL.path
    }
}
