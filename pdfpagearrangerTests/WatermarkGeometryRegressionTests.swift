import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class WatermarkGeometryRegressionTests: XCTestCase {
    private let tolerance: CGFloat = 0.02

    private func settings(
        text: String = "CONFIDENTIAL",
        normalizedScale: CGFloat = 0.35,
        rotationDegrees: CGFloat = 45,
        position: WatermarkPosition = .center
    ) -> WatermarkSettings {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.text = text
        settings.normalizedScale = normalizedScale
        settings.rotationDegrees = rotationDegrees
        settings.position = position
        return settings
    }

    private func renderSize(for mediaBox: CGRect, pageRotation: Int, maxDimension: CGFloat) -> CGSize {
        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: pageRotation,
            mediaBox: mediaBox
        )
        let scale = min(maxDimension / max(displaySize.width, displaySize.height), 1.0)
        return CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    }

    private func normalizedBounds(
        from concreteBounds: CGRect,
        renderSize: CGSize
    ) -> CGRect {
        CGRect(
            x: concreteBounds.minX / renderSize.width,
            y: concreteBounds.minY / renderSize.height,
            width: concreteBounds.width / renderSize.width,
            height: concreteBounds.height / renderSize.height
        )
    }

    private func normalizedBoundsFromPDF(
        pdfBounds: CGRect,
        mediaBox: CGRect,
        displaySize: CGSize
    ) -> CGRect {
        CGRect(
            x: (pdfBounds.minX - mediaBox.minX) / displaySize.width,
            y: (mediaBox.maxY - pdfBounds.maxY) / displaySize.height,
            width: pdfBounds.width / displaySize.width,
            height: pdfBounds.height / displaySize.height
        )
    }

    private func assertConsistentNormalizedGeometry(
        settings: WatermarkSettings,
        mediaBox: CGRect,
        pageRotation: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = settings.text
        let expected = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            text: text,
            pageRotation: pageRotation,
            mediaBox: mediaBox
        )
        XCTAssertNotNil(expected, file: file, line: line)
        guard let expected else { return }

        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: pageRotation,
            mediaBox: mediaBox
        )
        let thumbnailSize = renderSize(
            for: mediaBox,
            pageRotation: pageRotation,
            maxDimension: 240
        )
        let pageModeSize = renderSize(
            for: mediaBox,
            pageRotation: pageRotation,
            maxDimension: 2048
        )

        let thumbnailLayout = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            text: text,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: thumbnailSize,
            coordinateSpace: .topLeftOrigin
        )
        let pageModeLayout = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            text: text,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: pageModeSize,
            coordinateSpace: .topLeftOrigin
        )
        let exportLayout = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            text: text,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: displaySize,
            coordinateSpace: .pdfMediaBox
        )

        XCTAssertNotNil(thumbnailLayout, file: file, line: line)
        XCTAssertNotNil(pageModeLayout, file: file, line: line)
        XCTAssertNotNil(exportLayout, file: file, line: line)
        guard let thumbnailLayout, let pageModeLayout, let exportLayout else { return }

        let thumbnailBounds = normalizedBounds(from: thumbnailLayout.bounds, renderSize: thumbnailSize)
        let pageModeBounds = normalizedBounds(from: pageModeLayout.bounds, renderSize: pageModeSize)
        let exportBounds = normalizedBoundsFromPDF(
            pdfBounds: exportLayout.bounds,
            mediaBox: mediaBox,
            displaySize: displaySize
        )

        assertCGRectEqual(thumbnailBounds, pageModeBounds, name: "thumbnail vs page mode", file: file, line: line)
        assertCGRectEqual(thumbnailBounds, exportBounds, name: "thumbnail vs export", file: file, line: line)
        assertCGRectEqual(thumbnailBounds, expected.bounds, name: "thumbnail vs normalized", file: file, line: line)

        XCTAssertEqual(thumbnailLayout.rotationDegrees, expected.rotationDegrees, file: file, line: line)
        XCTAssertEqual(pageModeLayout.rotationDegrees, expected.rotationDegrees, file: file, line: line)
        XCTAssertEqual(exportLayout.rotationDegrees, expected.rotationDegrees, file: file, line: line)
    }

    private func assertCGRectEqual(
        _ actual: CGRect,
        _ expected: CGRect,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if abs(actual.minX - expected.minX) > tolerance
            || abs(actual.minY - expected.minY) > tolerance
            || abs(actual.width - expected.width) > tolerance
            || abs(actual.height - expected.height) > tolerance {
            XCTFail(
                "\(name) bounds \(actual) != expected \(expected)",
                file: file,
                line: line
            )
        }
    }

    func testPortraitPageNormalizedGeometryMatchesAcrossRenderTargets() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        assertConsistentNormalizedGeometry(
            settings: settings(),
            mediaBox: mediaBox,
            pageRotation: 0
        )
    }

    func testLandscapePageNormalizedGeometryMatchesAcrossRenderTargets() {
        let mediaBox = CGRect(x: 0, y: 0, width: 792, height: 612)
        assertConsistentNormalizedGeometry(
            settings: settings(text: "LANDSCAPE", position: .top),
            mediaBox: mediaBox,
            pageRotation: 0
        )
    }

    func testRotatedPageNormalizedGeometryMatchesAcrossRenderTargets() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        assertConsistentNormalizedGeometry(
            settings: settings(text: "ROTATED", rotationDegrees: 0, position: .bottom),
            mediaBox: mediaBox,
            pageRotation: 90
        )
    }

    func testMixedPageSizesUseSameNormalizedScale() {
        let letterBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let a4Box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let watermarkSettings = settings(text: "MIXED", normalizedScale: 0.30)

        let letterLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: watermarkSettings,
            text: watermarkSettings.text,
            pageRotation: 0,
            mediaBox: letterBox
        )
        let a4Layout = WatermarkGeometryEngine.normalizedLayout(
            settings: watermarkSettings,
            text: watermarkSettings.text,
            pageRotation: 0,
            mediaBox: a4Box
        )

        XCTAssertEqual(letterLayout?.scale, a4Layout?.scale)
        XCTAssertEqual(letterLayout?.bounds.width ?? 0, a4Layout?.bounds.width ?? 0, accuracy: tolerance)

        assertConsistentNormalizedGeometry(
            settings: watermarkSettings,
            mediaBox: letterBox,
            pageRotation: 0
        )
        assertConsistentNormalizedGeometry(
            settings: watermarkSettings,
            mediaBox: a4Box,
            pageRotation: 0
        )
    }

    func testWatermarkRendererUsesGeometryEngineOnly() throws {
        let rendererSource = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(rendererSource.contains("WatermarkGeometryEngine.concreteLayout"))
        XCTAssertFalse(rendererSource.contains("scaledFontSize"))
        XCTAssertFalse(rendererSource.contains("displayAnchor"))
        XCTAssertFalse(rendererSource.contains("pdfAnchor"))
    }

    private func projectSourceURL(file: String, subdirectory: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(file)
    }
}
