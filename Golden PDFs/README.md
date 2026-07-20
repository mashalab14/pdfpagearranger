# Golden PDFs

This folder holds **manual and regression test fixtures** for PDF Pages. These files are not production assets and should never be bundled with the app.

## Purpose

Use PDFs here to exercise:

- Import / Open Document into the unified vertical document editor
- Recent Documents reopen (external Files-backed documents)
- Pages organizer thumbnail grid (⋯ → Pages)
- Page operations (reorder, rotate, delete, duplicate, undo)
- Image / text / signature overlays and page annotations
- Document search (native and OCR-embedded text layers)
- Export (page order, overlays, selectable/searchable text; external originals unchanged by Export)
- Scan-to-PDF handoff validation against representative office scans
- Performance with large or complex documents

Most automated unit tests generate temp PDFs via `PDFTestFactory` and related helpers rather than reading this folder. Golden PDFs remain the preferred set for **manual** QA and future fixture-backed tests.

## Structure

| Folder | Contents |
|--------|----------|
| [Business/](Business/) | Real-world documents: contracts, reports, invoices, scanned office PDFs |
| [Technical/](Technical/) | Structure-focused PDFs: multi-page layouts, mixed orientations, embedded fonts, form fields |
| [Edge Cases/](Edge%20Cases/) | Unusual or fragile inputs: encryption, empty pages, extreme aspect ratios, corrupted or borderline files |
| [Performance/](Performance/) | Stress tests: high page counts, large file sizes, heavy vector or image content |

## Usage

- Add representative PDFs to the appropriate subfolder as the test suite grows.
- Prefer descriptive filenames (e.g. `MultiPage-Letter-12p.pdf`, `Scanned-Invoice-Password.pdf`).
- Future unit, integration, and UI tests may reference paths under this directory when fixture identity matters.
- Do not commit secrets or personal data; use synthetic or redacted samples when possible.
