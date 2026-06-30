# PDF Pages — Architecture

This document describes the product and technical architecture of **PDF Pages** (bundle: `com.abhisheksamanta.pdfpagearranger`). It is the reference mental model for future development, including Cursor-assisted changes.

---

## 1. Product philosophy

PDF Pages is a **local-first PDF transformation workspace**.

- The app **transforms existing PDFs** — it rearranges, edits, annotates, and exports them.
- The app **does not create PDFs from scratch** (no blank-document authoring flow).
- The app **does not extract structured data** from PDFs (no OCR pipeline, no field extraction, no document intelligence).
- **Original imported PDFs must remain untouched.** All editing happens in app state; output is a new file at export time.

Everything runs on-device. There is no cloud account, sync layer, or server-side processing in the current product.

---

## 2. Core hierarchy

The product is organized around four levels:

```
Project → Document → Page → Export
```

### Project *(future — not implemented)*

The future top level for working with **multiple PDFs** in one session.

Examples (planned, not built):

- Import several PDFs into one workspace
- Merge documents
- Reorder documents before export

Today the app operates at the **Document** level only. There is no multi-document project model yet.

### Document *(current main level)*

One imported PDF and its page list.

Examples (implemented):

- Import a PDF
- Reorder pages (drag-and-drop)
- Delete pages
- Rotate pages
- Duplicate pages
- Undo page-level operations
- View Document Mode thumbnail grid

**Current code:** a session in `PDFEditorViewModel` with `pages: [PageItem]`, `sourceDocument`, and overlay state keyed by page.

### Page *(single-page editing level)*

One page within a document. **Page overlays live here.**

Examples (implemented):

- Image/logo overlays (add, move, resize, delete)
- Undo overlay operations

Examples (planned, not built):

- Text overlays
- Signature overlays
- Page numbers, watermarks *(text and image watermark implemented)*

**Current code:** Page Mode (`PageEditorView`) edits overlays for one `PageItem`. Overlays are stored in `pageObjectsByPage[pageItemID]`.

### Export *(final output step)*

Export applies all stored operations and overlays and **writes a new PDF**. The source file on disk is never modified.

Examples (implemented):

- Export rearranged page order
- Export page rotation
- Export with image overlays composited on top
- Preserve selectable/searchable text where possible (vector page draw, not full-page rasterization)

**Current code:** `PDFEditorViewModel.exportPDF()` → `PDFService.exportPDF()`.

---

## 3. Non-destructive editing rule

**Rule:** Store operations and overlays in app state. Do not mutate the source PDF. Rebuild a new PDF only when the user taps Export.

How this works today:

1. **Import** copies the PDF to a temporary local path (`PDFService.importPDF`). The user’s original file is never written to.
2. **Editing** updates in-memory (and undo-snapshot) state: `PageItem` list, rotations, and `PageObject` overlays.
3. **Preview** (thumbnails, Page Mode) renders from the source `PDFDocument` plus app state.
4. **Export** builds a new `PDFDocument`, inserts transformed pages, and writes to a new temp output URL for sharing.

Never edit the imported source bytes in place. Never assume export output overwrites the import copy used for editing.

---

## 4. Current implementation mapping

| Concept | Role |
|--------|------|
| **`PageItem`** | One page in the document list. Stable `id`, `originalPageIndex` into the source PDF, `rotation`, optional `duplicateSourceID`. |
| **`PageObject`** | One overlay on a page (image today). Normalized `position` / `size`, `rotation`, `zIndex`, `imageAssetID`. |
| **`pageObjectsByPage`** | `[UUID: [PageObject]]` in `PDFEditorViewModel` — overlays keyed by `PageItem.id`. |
| **`EditorSnapshot`** | Undo entry: pages, overlays, overlay revisions, and image asset references. |
| **`PDFEditorViewModel`** | Session state, page ops, overlay ops, undo stack, export entry point. |
| **`PDFService`** | Import (copy to temp), export (assemble new PDF), initial `PageItem` list. |
| **`PDFPreviewRenderer`** | On-screen PDF page rasterization via `PDFPage.thumbnail` (correct orientation). |
| **`PageRenderService`** | High-resolution page image for Page Mode. |
| **`WatermarkType`** | Extensible watermark payload kind (V1: text, image; future: QR code, PDF page, stamp). |
| **`WatermarkSettings`** | Document-level watermark configuration (`watermarkType`, text, `imageAssetID`, opacity, normalized scale, color, rotation, position, layer, apply scope). |
| **`WatermarkGeometryEngine`** | Single source of truth for watermark normalized position, scale, rotation, and bounds across all watermark types; derives text font size or image content size from render target width. |
| **`WatermarkRenderer`** | Branches by `watermarkType`: text (vector PDF / raster preview), image (raster via `OverlayGeometryEngine`). Delegates placement to `WatermarkGeometryEngine`. |
| **`PageModeSelection`** | Page Mode focus: `none`, `overlay(UUID)`, or `pdfText(PDFTextSelection)` — separate from user overlays. |
| **`PDFTextSelectionEngine`** | Maps PDFKit selection bounds to Page Mode display coordinates for menu placement. |
| **`PDFPageTextSelectionView`** | Lazy-mounted `PDFView` for native text selection; disables internal scrolling; forwards page swipes when active. |
| **`ThumbnailService`** | Cached document thumbnails; composited with overlays when present. |
| **`OverlayCompositor`** | Draws image overlays onto a thumbnail/page bitmap using `OverlayGeometryEngine`. |
| **`OverlayPDFExporter`** | Draws image overlays into a PDF `CGContext` using `OverlayGeometryEngine`. |
| **`OverlayPlacementSizing`** | Initial normalized overlay size for signatures (PNG aspect–matched frame) and images (legacy formula). |
| **`OverlayGeometryEngine`** | Shared normalized → concrete rect mapping for Page Mode, thumbnails, and PDF export (including page rotation). |
| **`SignatureOverlayMenuEngine`** | Positions the signature contextual menu above the selected overlay within page bounds. |
| **`SignatureOverlayContextMenu`** | Floating Edit / Delete / More menu for selected signature overlays in Page Mode. |
| **`SignaturePlacementEngine`** | Converts Page Mode tap coordinates to clamped normalized signature position (`Signature Placement Mode`). |
| **`SignatureLibraryStore`** | On-device reusable signature assets (`signatures.json`), preferences (`library-preferences.json` for Default Signature ID), and `QuickSignatureResolution` for Quick Signature routing. |
| **`SignatureLibraryView`** | Library UI; holds `@State defaultSignatureID` for immediate Default Signature feedback; optional guidance banner when Quick Signature opens the library with multiple signatures and no default. |

### UI modes

| Mode | View | Purpose |
|------|------|---------|
| **Empty / Import** | `ContentView` | Choose a PDF |
| **Document Mode** | `EditorView` | Page grid, page ops, export |
| **Page Mode** | `PageEditorView` | Overlay editing on one page |

### Export pipeline (overlays, watermark, page numbers)

1. For pages **without** overlays, watermark, or page numbers: copy source `PDFPage`, apply rotation, insert.
2. For pages **with** decorations:
   - **Behind content** watermark (if enabled): rendered by `watermarkType` (text vector or image raster)
   - Source page vector content via `PDFPage.draw` (preserves selectable text)
   - **Above content** watermark (if enabled): rendered by `watermarkType`
   - Overlay images via `OverlayPDFExporter`
   - Page numbers
3. **Do not** use `PDFPage(image:)` for export — that rasterizes the page and destroys selectable text.

---

## 5. Coordinate systems

Overlays use **multiple coordinate spaces**. They must stay consistent or the same overlay will appear in different places in Page Mode, thumbnails, and export.

### Normalized overlay storage *(source of truth)*

Stored on `PageObject` relative to the **unrotated** page media box:

- `position`: normalized center, `(0,0)` top-left → `(1,1)` bottom-right
- `size`: width/height as fractions of unrotated page width and height
- `rotation`: overlay rotation in degrees (object-local)

Page rotation (`PageItem.rotation`) is applied at **render time**, not by mutating stored overlay coordinates on rotate.

### SwiftUI / Page Mode *(top-left origin)*

`PageEditorView` sizes the canvas with `PageModeLayoutSizing` (width fills safe area minus 16 pt margins; height from aspect ratio). `ImageOverlayObjectView` uses `OverlayGeometryEngine.pageModeLayout` to convert normalized storage → pixel center, size, and rotation on the fitted page canvas.

### Thumbnail coordinates *(top-left origin)*

`OverlayCompositor` uses `OverlayGeometryEngine.thumbnailLayout` — same mapping as Page Mode for a given render size — so grid previews match Page Mode.

### PDF export coordinates *(bottom-left origin)*

`OverlayPDFExporter` uses `OverlayGeometryEngine.pdfLayout` with the page media box. Y is flipped relative to SwiftUI (`maxY - normalizedY * height`).

### Why shared geometry matters

Previously, placement math was duplicated across Page Mode, thumbnails, and export. **`OverlayGeometryEngine`** centralizes:

- Rotation transforms (0°, 90°, 180°, 270°)
- Normalized → pixel rect conversion
- Top-left vs bottom-left coordinate spaces

Any new surface that renders overlays (e.g. a new preview or print path) must use `OverlayGeometryEngine`, not ad hoc math.

---

## 6. Regression rule

Quality is guarded by an automated regression suite (`PDFPagesTests`, `PDFPagesUITests`).

**Rules for all changes:**

1. **Every new feature must include regression coverage** (unit and/or UI tests as appropriate).
2. **During development**, run **focused tests** for the area you changed. Do not run the full suite before every commit.
3. **Before release or major architecture changes** (rendering, coordinates, export, undo, document model), run the **full regression suite** manually.
4. **New features should update the regression checklist** (and `Golden PDFs/` fixtures when manual PDFs are relevant).

### Testing workflow

| When | What to run |
|------|-------------|
| **Normal commit** | Focused tests for your change + `xcodebuild build`. The **pre-commit hook** runs only a **fast compile check** (~seconds). |
| **Optional focused tests on commit** | `PRE_COMMIT_ONLY_TESTING="PDFPagesTests/MyTests" git commit` (space-separated `-only-testing:` targets). |
| **Optional full regression on commit** | `RUN_FULL_REGRESSION=1 git commit` |
| **Manual full regression** | `./scripts/run-full-regression.sh` |
| **Release / shared infrastructure** | `./scripts/run-full-regression.sh` (required) |

The pre-commit hook (`scripts/pre-commit`, symlinked from `.git/hooks/pre-commit`) must **not** run the full simulator regression suite by default.

Test helpers live under `pdfpagearrangerTests/Helpers/` (`PDFTestFactory`, `OverlayTestFactory`, `ExportAssertions`). Prefer extending these over one-off test setup.

---

## 7. Future boundaries

### Belongs in PDF Pages

- Organize existing PDFs (reorder, delete, rotate, duplicate, merge/split later)
- Add overlays: images, logos, text, signatures
- Page numbers and watermarks
- Compress / optimize export
- Merge and split workflows (document/project level)
- Secure export workflows (e.g. password, permissions — when implemented)
- Local, on-device processing

### Does not belong in PDF Pages

- OCR / document intelligence
- Bank statement extraction
- Salary slip / payslip extraction
- JSON-to-PDF or template document generation from scratch
- Cloud collaboration, shared workspaces, accounts
- Full Word-style reflow text editing inside PDFs
- Any feature that mutates or uploads the user’s original source file without explicit user action

When in doubt: if it **transforms an imported PDF locally** and **exports a new file**, it likely belongs. If it **creates**, **extracts structured data**, or **requires cloud identity**, it does not.

---

## Related repo assets

| Path | Purpose |
|------|---------|
| `Golden PDFs/` | Manual/regression PDF fixtures (by category) |
| `pdfpagearrangerTests/` | Unit regression tests (`PDFPagesTests`) |
| `pdfpagearrangerUITests/` | UI regression tests (`PDFPagesUITests`) |
| `scripts/pre-commit` | Fast compile check on commit (not full regression) |
| `scripts/run-full-regression.sh` | Manual full regression suite (`xcodebuild test`) |

---

*Last updated to reflect OverlayGeometryEngine, overlay undo snapshots, and the Project → Document → Page → Export hierarchy.*
