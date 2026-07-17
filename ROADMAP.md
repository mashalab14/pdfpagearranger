# PDF Pages — Roadmap

## Implemented

- Document Mode (import, reorder, delete, duplicate, rotate)
- Page Mode (overlays, zoom, swipe navigation)
- **Scan-to-PDF workflow** — Home presents VisionKit and system Photos picker directly; Draft Review opens after successful acquisition; page adjustment, PDF generation, handoff to editor as **app-owned** Recent entries
- **Recent Documents** — Home lists recently opened/created PDFs with More list; Files-first index (bookmarks for external PDFs, app-owned storage for Create Document / scan-photo outputs); Create Document blank PDF entry point
- **Open In…** — PDF document type registration + `onOpenURL` → `handleIncomingDocumentURL` (external ownership; always copies to temp working file)
- **Searchable PDF OCR (scan-to-PDF)** — on-device Vision text recognition; invisible text layer in generated PDFs; Make PDF Searchable toggle on Draft Review (default on, persisted)
- Image overlays
- **Text overlays (V1)** — tap-to-place editable text with formatting, Recent Texts, vector export
- **Page annotations (V1)** — PDF text highlights, freehand drawing mode, tap-to-place sticky notes, text comments from PDF selection; composited in Page Mode, thumbnails, and export
- **Document search** — incremental find across native PDF text and OCR-embedded text; Document Mode results list and Page Mode prev/next navigation with temporary highlights
- Signature library, Quick Signature, default signature, stroke thickness
- Page numbers (document-level)
- **Text and image watermark (document-level)** — including above/behind content layer placement; image stored in session `imageAssets` via `imageAssetID`
- Compression (metadata optimization); Continue Editing on external sessions creates a new app-owned Recent entry
- Export with vector page preservation; **app-owned** authoritative file write-back on Export / Compress prep; **external** Files originals not written by Export
- Document Actions **Export** paywall at 20 pages (placeholder); Compression Save/Share is currently ungated
- **Shared Undo and Redo** — one document-session history used from Document Mode and Page Mode; up to 50 undo and 50 redo steps; restores pages, overlays, annotations, page numbers, watermarks, and session image assets

## Planned / not implemented

- Split / merge PDFs
- Password protect
- Document rename and information panel
- Project save / multi-document workspace (beyond Recent Documents index)
- Share Extension (wire into existing incoming-document import path)
- Home Drafts surface (reuse Recent index `kind: draft` / app-owned storage)
- In-place write-back to external Files originals on Export (today share-only for external)
- Custom watermark fonts
- Batch tools
- Real in-app purchase (and consistent paywall on all share paths)
