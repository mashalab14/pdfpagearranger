# PDF Pages — Architecture

This document describes the product and technical architecture of **PDF Pages** (bundle: `com.abhisheksamanta.pdfpagearranger`). It is the reference mental model for future development, including Cursor-assisted changes.

---

## 1. Product philosophy

PDF Pages is a **local-first PDF transformation workspace**.

- The app **transforms existing PDFs** — it rearranges, edits, annotates, and exports them.
- The app can **create PDFs from camera scans or photos** via the scan-to-PDF workflow (draft review → generate → open in editor).
- The app can **create a blank PDF** via **Create Document** on Home.
- Home is an **acquisition funnel** (Recent Documents + open/create/scan/photo), not a feature toolbox.
- **Files-first:** externally owned PDFs remain owned by the user; Recent Documents indexes them via bookmarks and must never become a second evolving copy (“hostage library”).
- The app runs **on-device OCR only during scan-to-PDF generation** to embed an invisible searchable text layer. In-editor **document search** reads the PDF text layer (native or OCR-embedded) via PDFKit; it does not run OCR on imported PDFs or extract structured fields.
- **Editing never mutates mid-session source bytes.** Import always copies into a temp working file. **Export** builds a new PDF for sharing. **External** Files originals are **not** written by Export. **App-owned** authoritative files **are** overwritten on Export (and when Compress preparation runs the same export pipeline).

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
- View the document as a continuous vertically scrolling editable surface
- Organize pages in the Pages sheet (thumbnails, reorder, rotate, duplicate, delete)
- Search document text from the unified document editor

**Current code:** a session in `PDFEditorViewModel` with `pages: [PageItem]`, `sourceDocument`, and overlay state keyed by page.

### Page *(single-page editing level)*

One page within a document. **Page overlays live here.**

Examples (implemented):

- Image/logo overlays (add, move, resize, rotate, delete)
- Text overlays (add, edit, move, resize, rotate, duplicate, delete)
- Signature overlays (add, move, resize, delete; edit appearance per placement)
- **Page annotations (V1)** — text highlights, freehand drawing, sticky notes, and text comments anchored to PDF text selection
- Undo overlay and annotation operations
- Page numbers, watermarks *(document-level; text and image watermark implemented)*

**Current code:** The unified document surface (`EditorView` → `PageEditorView` with `isUnifiedDocumentSurface`) edits overlays and annotations on the **active** `PageItem` while showing surrounding pages in a vertical scroller. Overlays are stored in `pageObjectsByPage[pageItemID]`. Annotations are stored in `annotationsByPage[pageItemID]`.

### Export *(final output step)*

Export applies all stored operations and overlays, **writes a new PDF** to a temporary share URL, and — when `activeDocumentOrigin` is **`.appOwned`** — **also overwrites** the authoritative `appOwned/{id}.pdf` via `RecentDocumentsStore.replaceAppOwnedFile`. **External** Files originals are **not** modified.

Examples (implemented):

- Export rearranged page order
- Export page rotation
- Export with image, text, and signature overlays composited on top
- Export with page annotations (highlights, drawings, sticky-note markers, text-comment anchors) composited above vector page content
- Preserve selectable/searchable text where possible (vector page draw, not full-page rasterization; scan-generated PDFs may include invisible OCR text layer)
- App-owned write-back on Export / Compress prep; share sheet still uses the temp file

**Current code:** `PDFEditorViewModel.exportPDF()` → `PDFService.exportPDF()` → optional `replaceAppOwnedFile`.

---

## 3. Non-destructive editing rule

**Rule:** Do not mutate PDF bytes **during editing**. Rebuild a new PDF when the user exports (or when Compress preparation runs the export pipeline). Then apply ownership-specific write-back.

How this works today:

1. **Import** copies the PDF to a temporary local path (`PDFService.importPDF` → `PDFImports/{uuid}.pdf`). External Files originals and app-owned authoritative files are not edited in place mid-session.
2. **Editing** updates in-memory (and undo-snapshot) state: `PageItem` list, rotations, `PageObject` overlays, and `PageAnnotation` annotations.
3. **Preview** (thumbnails, Page Mode) renders from the session `PDFDocument` plus app state.
4. **Export** builds a new `PDFDocument` and writes a temp share URL. If `activeDocumentOrigin == .appOwned`, those bytes are also copied to `appOwned/{id}.pdf` (`try?` — failures are silent). External origins have **no** write-back.

Never edit the temp working copy’s “source” semantics by assuming Export updates external Files. Never keep a second evolving library copy of an external PDF in Recent storage.

---

## 3.1 Recent Documents (Files-first index)

Recent Documents is an **index into documents**, not an app-managed document library.

```
Acquisition → active document → RecentDocumentsStore.recordActiveDocument
                                      ├─ external → bookmark + metadata (+ thumbnail)
                                      └─ appOwned  → appOwned/{id}.pdf + metadata (+ thumbnail)
Reopen Recent → resolve bookmark / app file → importPDF (working temp) → bump Recent
```

| Ownership | Examples | Authoritative bytes | Recent persistence |
|-----------|----------|---------------------|--------------------|
| **External** | Open Document, Open In… (future Share Extension → same path) | User's file | Bookmark + path + metadata + optional thumbnail |
| **App-owned** | Create Document, Scan/Photo after Create PDF | `Application Support/RecentDocuments/appOwned/` | Relative path + metadata + optional thumbnail |
| **Draft** *(future)* | Home Drafts | App-owned draft files | Same store; `RecentDocumentKind.draft` |

**Identity:** `identityKey` is `external:<standardizedPath>` or `appOwned:<uuid>`. Identical content at different paths yields different entries. Content hashing is intentionally **not** used.

**Save / reopen trust:**

- Opening a Recent entry always resolves the live authoritative file (bookmark or `appOwned` path), then copies into a new temp working file.
- **Export** does **not** write back to **external** originals.
- **Export** (and **Compress preparation**, which calls `exportPDF()`) **does** replace the app-owned authoritative file when `activeDocumentOrigin` is `.appOwned`.
- **Compression Continue Editing** (`adoptCompressedPDF`):
  - `.appOwned` → replace same id, re-import from `appOwned/`
  - `.external` / `.none` → import compressed PDF as a **new** `.appOwned` Recent entry (original external Recent row and Files file unchanged)

**Migration (schema v2):** On store init, legacy `files/` directory (v1 durable PDF library) is deleted if present. `loadIndexLocked` returns an empty list when `index.json` is missing, undecodable, or `schemaVersion != 2` (a leftover v1 index file may remain on disk unread until overwritten by a new save).

**Minimal integration for new acquisition:** call `importPDF(from:ownership:)` or `handleIncomingDocumentURL(_:)` so recording stays centralized.

**Create Document:** `RecentDocumentsStore.createAppOwnedBlankDocument` writes the blank PDF under `appOwned/` first; `PDFService.createBlankPDF` exists but is unused by the product path.

---

## 4. Current implementation mapping

| Concept | Role |
|--------|------|
| **`PageItem`** | One page in the document list. Stable `id`, `originalPageIndex` into the source PDF, `rotation`, optional `duplicateSourceID`. |
| **`PageObject`** | One overlay on a page (image, text, or signature). Normalized `position` / `size`, `rotation`, `opacity`, `zIndex`, `imageAssetID`. Text overlays store `textContent`, whole-overlay style defaults, optional `textSpans` for mixed rich text, list mode/indent, and font family. Signatures may also store `signatureSourceImageAssetID`, library baseline appearance, and per-placement ink color/thickness overrides. |
| **`PageAnnotation`** | One non-overlay annotation on a page: highlight (multi-rect), drawing (strokes), sticky note (point + text), or text comment (anchor rects + text). Coordinates stored normalized to the unrotated page. |
| **`pageObjectsByPage`** | `[UUID: [PageObject]]` in `PDFEditorViewModel` — overlays keyed by `PageItem.id`. |
| **`annotationsByPage`** | `[UUID: [PageAnnotation]]` in `PDFEditorViewModel` — annotations keyed by `PageItem.id`. |
| **`EditorSnapshot`** | History entry: pages, overlays, annotations, overlay revisions, image assets, page numbers, and watermark settings. |
| **`PDFEditorViewModel`** | Session state, page ops, overlay ops, shared undo/redo stacks, export entry point, document search state. |
| **`DocumentSearchEngine`** | Shared document-wide text search over PDFKit page text (native + OCR-embedded). Case/diacritic insensitive; returns normalized match geometry via `PDFTextSelectionEngine`. |
| **`DocumentSearchState`** | Ephemeral search UI state in `PDFEditorViewModel` (query, matches, current index). Not part of undo snapshots or export. |
| **`SearchHighlightRenderer`** | Temporary orange search highlights in Page Mode only (distinct from permanent highlight annotations). |
| **`PDFService`** | Import (copy to temp `PDFImports/`), export (assemble new PDF to temp share URL), initial `PageItem` list. `createBlankPDF` exists but Create Document uses `RecentDocumentsStore.createAppOwnedBlankDocument` instead. |
| **`PDFPreviewRenderer`** | On-screen PDF page rasterization via `PDFPage.thumbnail` (correct orientation). |
| **`PageRenderService`** | High-resolution page image for Page Mode. |
| **`DocumentScrollNavigationEngine`** | Active-page detection and scroll targets for the unified vertical document surface. |
| **`WatermarkType`** | Extensible watermark payload kind (V1: text, image; future: QR code, PDF page, stamp). |
| **`WatermarkSettings`** | Document-level watermark configuration (`watermarkType`, text, `imageAssetID`, opacity, normalized scale, color, rotation, position, layer, apply scope). |
| **`WatermarkGeometryEngine`** | Single source of truth for watermark normalized position, scale, rotation, and bounds across all watermark types; derives text font size or image content size from render target width. |
| **`WatermarkRenderer`** | Branches by `watermarkType`: text (vector PDF / raster preview), image (raster via `OverlayGeometryEngine`). Delegates placement to `WatermarkGeometryEngine`. |
| **`PageModeSelection`** | Page Mode focus: `none`, `overlay(UUID)`, `pdfText(PDFTextSelection)`, `highlight(UUID)`, `drawing(UUID)`, `stickyNote(UUID)`, or `textComment(UUID)` — only one active at a time. |
| **`PDFTextSelectionEngine`** | Maps PDFKit selection bounds to normalized storage rects and Page Mode display coordinates for menu placement. |
| **`AnnotationGeometryEngine`** | Normalized ↔ display mapping for annotations (reuses rotation rules complementary to `OverlayGeometryEngine`). |
| **`AnnotationRenderer`** | Draws highlights, drawings, sticky-note markers, and text-comment anchors for Page Mode and thumbnails. |
| **`AnnotationPDFExporter`** | Draws annotations into PDF export `CGContext` using PDF media-box coordinates. |
| **`AnnotationCompositor`** | Composites annotations onto thumbnail/page bitmaps. |
| **`AnnotationHitTestEngine`** | Tap hit testing for annotation selection and stroke erasing. |
| **`PDFPageTextSelectionView`** | Lazy-mounted `PDFView` for native text selection; disables internal scrolling; forwards page swipes when active. |
| **`ThumbnailService`** | Cached document thumbnails; composited with overlays and annotations when present. |
| **`OverlayCompositor`** | Draws image overlays onto a thumbnail/page bitmap using `OverlayGeometryEngine`. |
| **`OverlayPDFExporter`** | Draws image and text overlays into a PDF `CGContext` using `OverlayGeometryEngine` and `TextOverlayRenderer`. |
| **`TextOverlayRenderer`** | Vector text drawing for Page Mode compositing, thumbnails, and PDF export. |
| **`TextOverlayLayoutEngine`** | Font sizing, measured bounds, attributed string layout for text overlays. |
| **`TextOverlayFormattingEngine`** | List prefixes (bulleted/numbered/dashed), indentation, Insert Date, list-mode switching. |
| **`TextOverlayRichTextEngine`** | Contiguous rich-text spans, selection apply/merge, attributed-string build for edit/render/export. |
| **`TextOverlayListEditingEngine`** | Plain↔display list-marker mapping for inline editing so markers stay visible while typing. |
| **`TextOverlayInlineEditor` / `TextOverlayFormatBar`** | On-page UITextView editing and Freeform-style compact formatting bar with progressive disclosure menus (Aa / BIU / alignment / lists / more / Insert Date), including opacity and range formatting. Object chrome stays outside the typing toolbar. |
| **`RecentDocumentsStore`** | Files-first recent **index** under Application Support (`RecentDocuments/`). Externally owned: security-scoped bookmark + metadata + optional thumbnail (no PDF library copy). App-owned (`appOwned/`): Create Document and Scan/Photo outputs. Identity by stable path / app id — **not** content hash. Schema v2; legacy `files/` removed on migrate; non-v2 index ignored. Drafts can share the index via `kind: draft` later. Max 50 entries (eviction deletes app-owned PDFs + thumbnails). |
| **`ActiveDocumentOrigin`** | Session tag on `PDFEditorViewModel`: `.external` vs `.appOwned` for export write-back and compression adopt. |
| **`handleIncomingDocumentURL`** | Open In… / future Share Extension entry → `importPDF(..., ownership: .external)`. |
| **`RecentTextsSettings`** | UserDefaults-backed Recent Texts list (max 10 entries). |
| **`ScanDraftSessionViewModel`** | Scan-to-PDF draft session: acquisition, review, adjustment, PDF generation, editor handoff. For **Scan to PDF**, draft disk storage is created only after a successful VisionKit scan returns pages. |
| **`ScanDraftPDFGenerator`** | Raster page assembly + optional OCR text layer embedding. |
| **`ScanOCRService`** | On-device Vision OCR with fingerprinted cache per draft page. |
| **`ScanOCRPDFTextRenderer`** | Invisible text layer drawing in generated scan PDFs. |
| **`ScanOCRSettings`** | Persisted **Make PDF Searchable** preference (default on). |
| **`OverlayPlacementSizing`** | Initial normalized overlay size for signatures (PNG aspect–matched frame) and images (legacy formula). |
| **`OverlayGeometryEngine`** | Shared normalized → concrete rect mapping for Page Mode, thumbnails, and PDF export (including page rotation). |
| **`SignatureAppearanceEngine`** | Recolors and thickens/thins placed signature rasters from an immutable source image. |
| **`SignaturePlacementContext`** | Baseline ink color/thickness and optional library source ID captured at placement time. |
| **`SignatureOverlayMenuEngine`** | Positions the signature contextual menu above the selected overlay within page bounds. |
| **`SignatureOverlayContextMenu`** | Floating Edit / Delete / More menu for selected signature overlays in Page Mode. |
| **`SignatureEditPopoverEngine`** | Positions the floating signature edit popover above or below the selected overlay within page bounds. |
| **`PlacedSignatureEditPopover`** | Markup-style floating row: preset colors, native advanced color picker, thickness steppers; live preview. |
| **`SignatureUIColorPicker`** | SwiftUI wrapper for `UIColorPickerViewController`. |
| **`SignaturePlacementEngine`** | Validates page-bound taps and converts Page Mode display coordinates to clamped normalized signature position (invisible tap-to-place arming). |
| **`SignatureLibraryStore`** | On-device reusable signature assets (`signatures.json`), preferences (`library-preferences.json` for Default Signature ID), and `QuickSignatureResolution` for Quick Signature routing. |
| **`SignatureLibraryView`** | Library UI; holds `@State defaultSignatureID` for immediate Default Signature feedback; optional guidance banner when Quick Signature opens the library with multiple signatures and no default. |

### UI modes

| Mode | View | Purpose |
|------|------|---------|
| **Empty / Import** | `ContentView` | Recent Documents, Open Document, Create Document, Scan to PDF, Photo to PDF; Home presents VisionKit and Photos picker directly |
| **Scan-to-PDF** | `ScanDraftRootView` | Draft review, page adjustment, PDF generation (opens after successful home acquisition) |
| **Document Editor** | `EditorView` + `PageEditorView` | Unified vertically scrolling editable pages; document … menu; page toolbar for the active page |
| **Pages organizer** | `DocumentPagesOrganizerSheet` | Thumbnail grid for reorder / rotate / duplicate / delete without leaving the document |

### Export pipeline (overlays, watermark, page numbers)

1. For pages **without** overlays, annotations, watermark, or page numbers: copy source `PDFPage`, apply rotation, insert.
2. For pages **with** decorations:
   - **Behind content** watermark (if enabled): rendered by `watermarkType` (text vector or image raster)
   - Source page vector content via `PDFPage.draw` (preserves selectable text)
   - Page annotations via `AnnotationPDFExporter` (highlights → drawings → text-comment anchors → sticky-note markers)
   - **Above content** watermark (if enabled): rendered by `watermarkType`
   - Overlay images and vector text via `OverlayPDFExporter` / `TextOverlayRenderer`
   - Page numbers
3. **Do not** use `PDFPage(image:)` for export — that rasterizes the page and destroys selectable text.

---

## 5. Undo and Redo (shared document session)

**Rule:** Document Mode and Page Mode share **one** document-session history. There is no separate Page Mode stack, annotation stack, or per-page history.

### Stacks

| Stack | Role |
|-------|------|
| **Undo stack** | Snapshots captured **before** each undoable edit (`EditorSnapshot`). Undo pops the latest snapshot and restores it. |
| **Redo stack** | Snapshots captured **before** each Undo or Redo operation. Redo pops the latest snapshot and restores it. |
| **Current state** | Live `PDFEditorViewModel` session fields (pages, overlays, annotations, assets, page numbers, watermark). |

Maximum depth for **both** stacks: **`EditorSnapshot.maxHistoryDepth` (50)**. Oldest entries are dropped when exceeded.

### Recording flow

1. Before a committed undoable mutation: `pushUndoSnapshot()` captures current state onto the undo stack and **clears the redo stack**.
2. Apply the mutation.
3. Grouped gestures (page reorder drag, overlay move/resize release, completed drawing session) call `pushUndoSnapshot()` once per completed interaction — not per frame.

Undo and Redo themselves do **not** create new history entries beyond moving snapshots between stacks.

### Restoration flow

`undo()` / `redo()`:

1. No-op if the target stack is empty.
2. Push **current** state onto the opposite stack (trim if needed).
3. Pop and `applySnapshot(_:)` — atomic replacement of all editable session fields.
4. Increment `historyRevision` (Page Mode observes this for page validity, selection clearing, and render refresh).
5. Clear thumbnail cache; refresh document search if active.

Temporary UI state (selection, search focus, placement modes, uncommitted drawing strokes, zoom/pan) is **not** in snapshots. Page Mode clears incompatible transient state before validating page route and selection after history changes.

### Asset retention

`isImageAssetReferenced(_:)` checks **current state plus every snapshot in undo and redo stacks** before `releaseImageAssetIfUnreferenced` deletes session image data. Assets reachable only from history remain until all three (current, undo, redo) no longer reference them.

### Session reset

Both stacks are cleared on: new import, **New PDF**, **Continue Editing** after compression (re-import), `closeSession()`, and app restart (history is not persisted).

---

## 6. Coordinate systems

Overlays use **multiple coordinate spaces**. They must stay consistent or the same overlay will appear in different places in Page Mode, thumbnails, and export.

### Normalized overlay storage *(source of truth)*

Stored on `PageObject` relative to the **unrotated** page media box:

- `position`: normalized center, `(0,0)` top-left → `(1,1)` bottom-right
- `size`: width/height as fractions of unrotated page width and height
- `rotation`: overlay rotation in degrees (object-local)

Page rotation (`PageItem.rotation`) is applied at **render time**, not by mutating stored overlay or annotation coordinates on rotate.

### Annotation storage *(source of truth)*

Stored on `PageAnnotation` relative to the **unrotated** page media box:

- Highlights and text comments: one or more normalized rectangles (`PageNormalizedRect`)
- Drawings: strokes of normalized points and normalized line width (fraction of page width)
- Sticky notes: normalized anchor point (`PageNormalizedPoint`) plus note text

`AnnotationGeometryEngine` mirrors the overlay rotation transform rules for annotation render surfaces.

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

## 7. Regression rule

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

Test helpers live under `pdfpagearrangerTests/Helpers/` (e.g. `PDFTestFactory`, `OverlayTestFactory`, `ExportAssertions`, `CompressionAssertions`, `ScanDraftTestFactory`, `ScanOCRTestDoubles`, `SignatureAssetTestFactory`). Prefer extending these over one-off test setup.

---

## 8. Future boundaries

### Belongs in PDF Pages

- Organize existing PDFs (reorder, delete, rotate, duplicate, merge/split later)
- Create PDFs from camera scans or photos (scan-to-PDF workflow)
- Add overlays: images, logos, text, signatures
- On-device OCR text layer for scan-generated PDFs (searchable output)
- Page numbers and watermarks
- Compress / optimize export
- Merge and split workflows (document/project level)
- Secure export workflows (e.g. password, permissions — when implemented)
- Local, on-device processing

### Does not belong in PDF Pages

- OCR / document intelligence on **imported** PDFs (scan-to-PDF OCR is in scope)
- Bank statement extraction
- Salary slip / payslip extraction
- JSON-to-PDF or template document generation from scratch
- Cloud collaboration, shared workspaces, accounts
- Full Word-style reflow text editing inside PDFs
- Any feature that uploads the user’s Files original without explicit user action
- Silently mutating **external** Files PDFs on Export (today Export does not write back to external originals; app-owned write-back on Export is intentional and user-initiated via Export / Compress prep)

When in doubt: if it **transforms a PDF locally** and **exports a new file** (with Files-first ownership rules), it likely belongs. If it **extracts structured data** or **requires cloud identity**, it does not.

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

*Last updated to reflect Files-first Recent Documents (external bookmarks vs app-owned write-back), Open In…, document search, V1 page annotations, scan-to-PDF with searchable OCR, V1 text overlays, and the Project → Document → Page → Export hierarchy.*
