# PDF Pages — Roadmap

## Implemented

- Document Mode (import, reorder, delete, duplicate, rotate)
- Page Mode (overlays, zoom, swipe navigation)
- **Scan-to-PDF workflow** — home entry via Scan to PDF or Photo to PDF; VisionKit presented immediately from home; draft review, page adjustment, PDF generation, handoff to editor
- **Searchable PDF OCR (scan-to-PDF)** — on-device Vision text recognition; invisible text layer in generated PDFs; Make PDF Searchable toggle (default on, persisted)
- Image overlays
- **Text overlays (V1)** — tap-to-place editable text with formatting, Recent Texts, vector export
- **Page annotations (V1)** — PDF text highlights, freehand drawing mode, tap-to-place sticky notes, text comments from PDF selection; composited in Page Mode, thumbnails, and export
- **Document search** — incremental find across native PDF text and OCR-embedded text; Document Mode results list and Page Mode prev/next navigation with temporary highlights
- Signature library, Quick Signature, default signature, stroke thickness
- Page numbers (document-level)
- **Text and image watermark (document-level)** — including above/behind content layer placement; image stored in session `imageAssets` via `imageAssetID`
- Compression (metadata optimization)
- Export with vector page preservation
- **Shared Undo and Redo** — one document-session history used from Document Mode and Page Mode; up to 50 undo and 50 redo steps; restores pages, overlays, annotations, page numbers, watermarks, and session image assets

## Planned / not implemented

- Split / merge PDFs
- Password protect
- Document rename and information panel
- Recent documents / project save
- Custom watermark fonts
- Batch tools
- Real in-app purchase
