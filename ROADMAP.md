# PDF Pages — Roadmap

## Implemented

- Document Mode (import, reorder, delete, duplicate, rotate)
- Page Mode (overlays, zoom, swipe navigation)
- **Scan-to-PDF workflow** — home entry via Scan Document or Import Photos; draft review, page adjustment, PDF generation, handoff to editor
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
- Undo (single-level stack)

## Planned / not implemented

- Split / merge PDFs
- Password protect
- Document rename and information panel
- Recent documents / project save
- Redo
- Custom watermark fonts
- Batch tools
- Real in-app purchase
