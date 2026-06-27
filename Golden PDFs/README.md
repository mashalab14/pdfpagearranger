# Golden PDFs

This folder holds **manual and regression test fixtures** for PDF Pages. These files are not production assets and should never be bundled with the app.

## Purpose

Use PDFs here to exercise:

- Import and Document Mode
- Thumbnail rendering
- Page operations (reorder, rotate, delete, duplicate, undo)
- Image overlays (add, move, resize, delete, persistence)
- Export (page order, overlays, selectable/searchable text)
- Performance with large or complex documents

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
- Future unit, integration, and UI tests may reference paths under this directory.
- Do not commit secrets or personal data; use synthetic or redacted samples when possible.
