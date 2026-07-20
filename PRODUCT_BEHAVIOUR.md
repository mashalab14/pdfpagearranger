# PDF Pages — Product Behaviour Specification

This document describes **exactly how the app behaves today** from the user's perspective. It is intended for designers, product managers, QA engineers, and other agents who need to understand the product without reading source code.

**Last verified against:** the codebase as of the current release (includes Files-first Recent Documents, Open In…, Create Document, scan-to-PDF with searchable OCR, Document Mode, Page Mode, image/text/signature overlays, Quick Signature and default/favorite, signature stroke thickness, page annotations, document search, page numbers, text and image watermark, compression, export, appearance settings, and the unified vertically scrolling document editor).

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [App launch and global behaviour](#2-app-launch-and-global-behaviour)
3. [Home / empty state (no document open)](#3-home--empty-state-no-document-open)
4. [Import (Open Document)](#4-import-open-document)
4.5. [Scan-to-PDF workflow](#45-scan-to-pdf-workflow)
4.6. [Open In…](#46-open-in)
5. [Settings](#5-settings)
6. [Document Editor (unified vertical surface)](#6-document-editor-unified-vertical-surface)
7. [Page thumbnails (Pages organizer)](#7-page-thumbnails-pages-organizer)
7.5. [Document search](#75-document-search)
8. [Page reordering](#8-page-reordering)
9. [Page rotate, duplicate, delete](#9-page-rotate-duplicate-delete)
10. [Document Actions menu](#10-document-actions-menu)
11. [Export](#11-export)
12. [Paywall (export limit)](#12-paywall-export-limit)
13. [Compression](#13-compression)
14. [Page Numbers](#14-page-numbers)
14.5. [Document Watermark](#145-document-watermark)
15. [Active page editing](#15-active-page-editing)
16. [Vertical page navigation](#16-vertical-page-navigation)
17. [Document zoom and pan](#17-document-zoom-and-pan)
18. [Adding content in Page Mode](#18-adding-content-in-page-mode)
19.4. [Page annotations (V1)](#194-page-annotations-v1)
19. [Image overlays](#19-image-overlays)
19.5. [Text overlays](#195-text-overlays)
20. [Signatures — library, drawing, placement](#20-signatures--library-drawing-placement)
21. [Overlay selection and manipulation](#21-overlay-selection-and-manipulation)
22. [Gesture reference (complete)](#22-gesture-reference-complete)
23. [Gesture priorities and conflicts](#23-gesture-priorities-and-conflicts)
24. [Undo and Redo](#24-undo-and-redo)
25. [Empty, loading, and error states](#25-empty-loading-and-error-states)
26. [Accessibility](#26-accessibility)
27. [Persistence and app restart](#27-persistence-and-app-restart)
28. [Limits and defaults](#28-limits-and-defaults)
29. [Known limitations](#29-known-limitations)
30. [Features not implemented](#30-features-not-implemented)

---

## 1. Product overview

**PDF Pages** is an iOS app for working with PDF documents. The user can:

- Open an existing PDF (**Open Document** or **Open In…** from another app)
- Create a blank PDF (**Create Document**)
- Reopen from **Recent Documents**
- Create a PDF from a **camera scan** or **imported photos** (scan-to-PDF workflow)
- View all pages in a scrollable grid (**Document Mode**)
- Reorder, rotate, duplicate, and delete pages
- Open a single page for detailed editing (**Page Mode**)
- Add **text**, image, and signature overlays on individual pages (including **Quick Signature** with tap-to-place when a default is set)
- Apply document-wide page numbers
- Apply document-wide text or image watermarks
- Compress the document
- Export a new PDF reflecting all changes
- Change app appearance (light / dark / device)
- Undo and redo many editing operations

**Editing is non-destructive to the session working copy:** every open copies the PDF into temporary app storage (`PDFImports/`). In-memory edits (pages, overlays, annotations, page numbers, watermarks) are applied at **Export** / compression prep time.

**Authoritative storage depends on ownership:**

| Ownership | Authoritative file | What Export does |
|-----------|--------------------|------------------|
| **External** (Open Document, Open In…) | User’s file in Files / another app | Builds a temp share file only — **does not** write back to the Files original |
| **App-owned** (Create Document; Scan/Photo after Create PDF) | `Application Support/RecentDocuments/appOwned/{id}.pdf` | Builds a temp share file **and** overwrites that app-owned file immediately (even if the user dismisses the share sheet) |

Scan-to-PDF drafts are stored in temporary on-device storage until discarded or converted to a PDF.

**Recent Documents** is a Files-first **index** into documents (bookmarks/metadata for externally owned PDFs; app-owned storage only for Create Document and other app-created PDFs). It is **not** an application-managed library of duplicated external files. There is still **no** full project saving, **no** multi-document simultaneous editing, and **no** account system.

---

## 2. App launch and global behaviour

### What the user sees

- On launch, the app opens in a **NavigationStack** (standard iOS navigation bar at the top).
- If no document is open: the **home / empty state** is shown.
- If a document were already open in the same session: Document Mode would still be shown (session is in-memory only; see [Persistence](#27-persistence-and-app-restart)).
- A **gear (Settings)** button appears in the **top-right** of the navigation bar on **every** screen (home and Document Mode).

### Appearance

- The app respects the user's **Appearance** setting (Device / Light / Dark). See [Settings](#5-settings).
- When set to **Device**, the app follows the system light/dark mode.

### Navigation structure

```
App
├── Home (empty) OR Document Editor (unified vertical scroll)
│   ├── Settings (sheet)
│   ├── Scan-to-PDF (full-screen cover: camera / photos → review → Create PDF → editor)
│   └── Pages organizer sheet (thumbnails / reorder)
│       ├── Add options (sheet: Text, Image, Quick Signature, Signature Library)
│       ├── Text editor (sheet)
│       ├── Photos picker (system)
│       ├── Signature Library (sheet)
│       └── Signature Capture (sheet, from library)
├── Compression (sheet, from Document Actions)
├── Page Numbers (sheet, from Document Actions)
├── Watermark (sheet, from Document Actions)
├── Paywall (sheet, from Export when over free limit)
└── Export share sheet (system share)
```

---

## 3. Home / empty state (no document open)

The Home screen is an **acquisition funnel**: it gets the user into a document. It is not a feature catalog or toolbox. Editing capabilities remain contextual inside an open document.

### Layout order

1. **Recent Documents** (visual focus)
2. **Open Document**
3. **Create Document**
4. **Scan to PDF**
5. **Photo to PDF**

(A future Digitize Document action may be added later; do not treat Home as a utilities surface.)

### What the user sees

- Large document icon (`doc.on.doc`)
- Title: **"PDF Pages"**
- Subtitle: **"Open, create, scan, or convert photos into PDFs."**
- **Recent Documents** section at the top (five most recent, with **More** when any exist)
- Acquisition buttons (stacked):
  - **Open Document**
  - **Create Document**
  - **Scan to PDF**
  - **Photo to PDF**
- Background: grouped system background (light grey in light mode)
- Settings gear in top-right

### Recent Documents

- Shows up to **five** most recently opened or created PDF documents (most recent first)
- Each row: filename, last opened date/time, thumbnail when available
- **More** opens the full Recent Documents list
- Selecting a row opens that PDF in the editor immediately from its **authoritative** location (external file via bookmark, or app-owned file)
- Empty state copy: *"Documents you open or create will appear here."*
- Acquisition actions remain available when the list is empty

**Ownership model**

| Kind | Authoritative file | What Recent stores |
|------|--------------------|--------------------|
| Externally owned (Open Document, Open In…; future Share Extension would use the same path) | User's file in Files / other app | Security-scoped bookmark + metadata + optional thumbnail (**no** PDF copy in the app library) |
| App-owned (Create Document; Scan/Photo after Create PDF) | App Application Support (`RecentDocuments/appOwned/`) | Relative path + metadata + optional thumbnail |
| Future Drafts | App-owned draft storage | Same index; `kind: draft` reserved (unused today) |

**Identity:** Recent represents **document identity** (stable path / app id), not file contents. Two different files with identical bytes remain separate entries. Reopening the same file updates one entry.

**Lifecycle:** A document becomes Recent whenever it becomes the **active** editor document (successful open/create/handoff). Cancelled acquisition flows are not recorded. Missing or unresolvable entries are pruned (and removed from the index). There is **no** user-facing delete control on the Recent list today.

**Save / reopen:**

- **External:** Reopen resolves the bookmark and opens whatever bytes are currently at that Files location. **Export does not update that file.** If the user never overwrites the Files original via Share → Save to Files (or another app), Recent reopen shows the **pre-edit** Files version. The share-sheet temp file is deleted when the sheet dismisses.
- **App-owned:** Export (and opening Compress, which runs the same export pipeline for size preview) **immediately overwrites** the authoritative `appOwned/{id}.pdf`. Compression **Continue Editing** on an already app-owned session replaces that same file. Reopen Recent loads those latest app-owned bytes.
- Editor sessions always use a **temporary working copy**; closing **New PDF** / closing the session deletes that temp copy only. Unexported in-memory edits are lost on close.

**Included** after an actual PDF exists: Open Document, Create Document, Scan to PDF (after Create PDF), Photo to PDF (after Create PDF), Open In…, reopening Recent.

**Not included:** cancelled scan/photo/open flows, temporary images, draft scan pages, unfinished acquisition.

### What the user can do

| Action | Result |
|--------|--------|
| Tap a **Recent Document** | Opens that PDF in the editor |
| Tap **More** | Opens the full Recent Documents list |
| Tap **Open Document** | Opens the system file picker limited to **PDF files**, **single selection only** |
| Tap **Create Document** | Creates a blank one-page PDF and opens it in the editor |
| Tap **Scan to PDF** | Opens Apple VisionKit document scanner immediately (camera permission dialog on first use only) |
| Tap **Photo to PDF** | Opens the system Photos picker immediately (Photos permission dialog on first use only) |
| Tap **Settings** | Opens Settings sheet |

Starting **Scan to PDF** or **Photo to PDF** from home **discards any in-progress scan draft** (temp files removed).

### If the user cancels Open Document import

- File picker closes
- User remains on home screen
- No error shown

---

## 4. Import (Open Document)

### Entry point

- **Open Document** button on home screen

### File picker behaviour

- Allowed types: **PDF only** (`.pdf`)
- **Multiple selection: not supported** — user can pick one file at a time
- Uses iOS security-scoped access for files from outside the app sandbox

### While importing

- A **semi-transparent dark overlay** covers the screen
- A centred card shows **"Importing PDF…"** with a spinning progress indicator
- User cannot interact with the app until import completes or fails

### On successful import

- User is taken directly to **Document Mode**
- Navigation title becomes the **file name without extension** (e.g. `Report` from `Report.pdf`)
- All pages from the PDF appear in the grid
- Undo and redo history are **cleared**
- Any previous overlays, page-number settings, and thumbnail cache are **reset**

### On failed import

An alert titled **"Import Failed"** appears with an **OK** button. Possible messages:

| Message | Meaning |
|---------|---------|
| Could not access the selected file. | Security-scoped access failed |
| Could not copy the PDF for editing. | Copy to app temp storage failed |
| This file could not be read as a PDF. | File is not a valid PDF |
| This PDF is password-protected and cannot be opened. | Encrypted PDF that cannot be unlocked with an empty password |
| This PDF has no pages. | Zero-page PDF |
| (System error text) | File picker or other system failure |

After dismissing **OK**, user returns to **home screen** (empty state). No partial document is shown.

### Re-import / New PDF

- Tapping **New PDF** in Document Mode closes the session and returns to home (see [Document Mode](#6-document-mode))
- Importing again replaces the entire session

### After app restart

- Import state is **not** restored. User sees home screen and must open or create a PDF again.

---

## 4.5 Scan-to-PDF workflow

Creates a new PDF from camera scans or imported photos, then opens it in the main editor. **Home** presents acquisition directly (VisionKit or the system Photos picker). **Draft Review** opens as a full-screen cover only after a successful import creates a non-empty draft. For **Scan to PDF**, the on-disk draft session directory is created only after a successful scan returns pages (no empty draft/session is created if the user cancels). Swipe-to-dismiss is **blocked** while the draft has unsaved changes or PDF generation is in progress.

### Entry points

| Entry | First screen |
|-------|----------------|
| Home → **Scan to PDF** | Apple VisionKit document scanner (presented immediately from Home; only interruption is iOS camera permission on first use) |
| Home → **Photo to PDF** | System Photos picker (presented immediately from Home; only interruption is iOS Photos permission on first use) |
| After successful import | **Draft Review** full-screen cover |
| Review → **Add Pages** → **Scan Document** / **Import Photos** | Same acquisition UI from Home; returns to review |

Starting a new scan/import from home **replaces any existing draft** silently.

### Scan to PDF (camera)

User journey:

**Home → Scan to PDF → Apple Document Scanner → Draft Review**

- VisionKit opens immediately after tap from Home (no intermediate acquisition shell)
- While pages import after scanning: **Importing scanned pages…** overlay on Home before Draft Review opens
- **Cancel with no pages** on a new draft → returns to Home (draft discarded)
- **Cancel with existing pages** (add-pages) → returns to **Review Pages**
- Unsupported device, denied camera, or scan failure → **Scan Error** alert on Home, then stays on Home when applicable
- First launch may show the **iOS camera permission** dialog before VisionKit

### Photo to PDF (photos import)

User journey:

**Home → Photo to PDF → System Photos Picker → Draft Review**

- System Photos picker opens immediately after tap from Home (no intermediate acquisition shell)
- While photos import after selection: **Importing photos…** or **Importing X of Y** overlay on Home before Draft Review opens
- **Cancel with no selection** on a new draft → returns to Home (draft discarded)
- **Cancel with existing pages** (add-pages) → returns to **Review Pages**
- Import failure → **Scan Error** alert on Home when applicable
- First launch may show the **iOS Photos permission** dialog before the picker
- Over-limit message: *"You can import up to 50 photos at once."*

Review → **Add Pages** → **Import Photos** or **Scan Document** reuses the same Home-owned acquisition presenters; acquisition routes inside Draft Review show import progress only.

### Review Pages

- Navigation title: **Review Pages**
- Large page preview, horizontal thumbnail strip (tap to select; drag to reorder when not in selection mode)
- Empty state: **No Pages Yet** — *"Scan a document or import photos to begin."* with **Scan Document**, **Import Photos**, **Cancel Draft**

**Toolbar (normal):** **Close** · **Rotate** · **Delete** · **Select** · **Create PDF**  
**Toolbar (selection mode):** **Close** · **Delete** · **Select All** · **Done**

**Bottom bar:** **Adjust Page** · **Duplicate** (hidden in selection mode) · **Add Pages**  
**Toggle:** **Make PDF Searchable** (default **on**; persisted across app launches)

| Control | Behaviour |
|---------|-----------|
| **Close** | Empty draft closes immediately; draft with pages → **Discard Draft?** confirmation |
| **Rotate** | Rotates selected page 90° clockwise |
| **Delete** | Deletes selected page(s); confirmation dialog |
| **Select** / **Done** | Enters/exits multi-page selection mode |
| **Create PDF** | Generates PDF and opens main editor (disabled during import, batch processing, or PDF generation) |
| **Adjust Page** | Opens per-page crop/appearance editor |
| **Duplicate** | Duplicates selected page |
| **Add Pages** | Dialog: **Scan Document** · **Import Photos** · **Cancel** |

**Discard Draft?** — *"This draft has unsaved changes. Discarding removes imported pages from this device."* — **Discard Draft** / **Keep Editing**

### Adjust Page

- Title: **Adjust Page N**
- Segmented control: **Crop** | **Appearance**
- **Crop:** draggable corner handles; **Rotate**; **Redetect** (photo imports) or **Reset** (camera scans)
- **Appearance:** **Mode** (Original / Enhanced / Grayscale / Black & White), **Brightness**, **Contrast**, optional **Saturation**, optional **Threshold** (B&W)
- Bottom bar: **Cancel** · **Apply**
- **Apply** → **Apply Settings To:** **This Page** · **Selected Pages** · **All Pages** · **Cancel**
- Batch apply confirmation: *"Apply [mode] and current adjustments to N pages? Page crops and rotations will remain unchanged."*

### Create PDF and editor handoff

1. User taps **Create PDF** on review
2. Progress screen titled **Create PDF** with phased labels:
   - **Preparing pages: page X of Y**
   - **Recognizing text: page X of Y** (when **Make PDF Searchable** is on)
   - **Creating PDF: page X of Y**
   - **Opening editor…**
3. **Cancel** available during generation (returns to review)
4. On success: scan cover **closes**; main editor opens with PDF named **Scanned Document**
5. If some pages could not be OCR'd: **PDF Created** alert — *"PDF created, but N page(s) may not be searchable."*
6. Failures: **Review Error** alert; user remains on review

### Searchable PDF (OCR)

- When **Make PDF Searchable** is enabled, the app runs **on-device Vision OCR** during PDF generation
- Recognized text is embedded as an **invisible text layer** over the rasterized page image (searchable/selectable in PDF readers)
- OCR results are **cached per draft page**; changing page crop/appearance invalidates cache for that page
- OCR applies only to **scan-generated PDFs**, not to imported existing PDFs in the editor
- Toggle preference is **persisted** in `UserDefaults` (default **on**). The control lives on the **Draft Review** bottom bar — **not** in the Settings sheet

### Persistence

| Data | Persists across restart? |
|------|--------------------------|
| **Make PDF Searchable** toggle preference | **Yes** |
| Scan draft pages / session | **No** (temp storage only; no resume) |

Draft files live under temporary app storage. Discarding or successful handoff removes them. Original photos in the user's library are **never modified**. Successful **Create PDF** handoff records an **app-owned** Recent Document (the generated PDF is copied into `RecentDocuments/appOwned/`).

---

## 4.6 Open In…

### Entry point

- Another app uses **Open In…** / “Copy to PDF Pages” / a PDF document link that launches this app (`onOpenURL`)
- The app registers as a PDF viewer (`Info-DocumentTypes.plist`: `com.adobe.pdf`, role Viewer, `LSSupportsOpeningDocumentsInPlace`)

### Behaviour

1. Incoming URL is handled by `handleIncomingDocumentURL` → same import path as Open Document (ownership **external**)
2. PDF is **copied** into temporary `PDFImports/` for editing (the app does **not** edit the caller’s file in place despite the in-place capability flag)
3. Document becomes the active session and is recorded in Recent Documents (bookmark to the external source when possible)
4. If a document was already open in this session, it is **replaced** (same as a new successful import)

### Errors

- Failures use the same **Import Failed** alert path as Open Document
- User returns to home if import fails

### Share Extension

- **Not implemented.** A future Share Extension should call the same incoming-document import path.

---

## 5. Settings

### Entry point

- **Gear icon** (top-right), available on home and Document Mode
- Accessibility label: **"Settings"**

### What the user sees

- Sheet titled **"Settings"**
- One section: **"Appearance"** (Device / Light / Dark only)
- **Make PDF Searchable** is **not** in Settings — it appears on Draft Review during scan-to-PDF
- **Done** button (top-right)

### Behaviour

| Option | Effect |
|--------|--------|
| **Device** (default) | App follows system appearance |
| **Light** | App always uses light mode |
| **Dark** | App always uses dark mode |

- Change takes effect **immediately** while the sheet is open (app-wide `preferredColorScheme`)
- Tapping **Done** dismisses the sheet
- Setting is **persisted** across app restarts via `UserDefaults`

### Cancel / dismiss

- User can swipe down on the sheet or tap **Done** — both dismiss without a confirmation dialog
- Appearance changes are **already saved** as the user switches the segmented control (no separate Save button)

---

## 6. Document Editor (unified vertical surface)

Shown when a document session is active (after import, create, open, or scan handoff).

There is **no separate Document Mode vs Page Mode navigation push**. The editor is one continuous vertically scrolling sequence of full editable pages.

### Chrome

| Placement | Controls |
|-----------|----------|
| **Leading** | New PDF, Search, Undo, Redo |
| **Trailing** | Document Actions **…** menu (Compress, Page Numbers, Watermark, Pages, Export) |
| **Floating page capsule** (bottom-leading) | Rotate / Duplicate / Delete **active page** — **ultra-thin material** matching top-bar translucency |
| **Floating Add** (bottom-trailing) | Compact circular Add control (material + muted accent), not a dominant filled FAB |

Floating page controls sit above the document (not attached to a bottom bar), respect the Home Indicator safe area, and **fade out while scrolling**, then fade back in shortly after scrolling stops. Inline text editing still replaces this chrome with the Freeform format bar. The **top toolbar** layout and interaction model are unchanged.

### Vertical document (paper stack)

- Pages appear **top to bottom** as equally scaled paper sheets in one continuous stack
- Active and inactive pages share the **same scale and layout footprint** (one shared slot-size calculation); activation never resizes a page
- Every sheet uses a consistent base shadow; the **active** sheet adds only a soft blue-tinted halo (**6 pt** blur radius, **0.8** opacity — no thick selection border for ordinary navigation)
- Workspace uses a consistent document background; pages are not framed as independent feed cards
- **Initial position:** opening a document scrolls to the **top** of the active page (page 1 for a new session, or the restored active page when the session already has one). The first frame is pinned without a post-launch corrective jump; lazy page loads re-pin while suppressed
- **Vertical snapping:** free scrolling while dragging; when the gesture/deceleration ends, the document settles to the top of the page chosen by the activation band / nearest-center rule. Search, Pages-organizer, tap activation, and other programmatic navigation use the same resting anchor
- Active page (and the page-position indicator) update as part of that settled navigation state — not from mid-scroll visibility flicker
- Programmatic navigation suppresses stale scroll-visibility callbacks so they cannot immediately override the intended page
- Single-page documents stay stable and do not run unnecessary settle snaps
- **Document zoom:** one shared magnification (1×–4×) owned by the document surface. Pinching anywhere zooms every page uniformly via scaled layout frames and scaled page gaps (pages never overlap). Double-tap resets to fitted width. Switching the active page does not reset zoom
- **Zoom navigation:** at fitted width, vertical page snapping works as above. While magnified, the document allows free horizontal and vertical panning; vertical page snaps are suppressed (active page still tracks the viewport). Returning to fitted width resumes snapping
- Overlay and annotation coordinates stay **page-normalized**; document zoom is display-only and does not change export geometry
- Document scrolling is prioritized over page gestures except when interacting with an editable object
- Search matches and Pages-organizer selection scroll to / activate the target page at the shared resting position without resetting document zoom
- Rotation, duplication, deletion, insertion, and reordering keep a sensible active page (delete activates the nearest remaining neighbour)

### Page-level vs document-level actions

| Scope | Where |
|-------|--------|
| **Document** | Top-right **…** menu |
| **Active page** | Floating page capsule (rotate, duplicate, delete) and overlay editing on the active canvas |
| **Add content** | Compact floating circular Add button |

## 7. Page thumbnails (Pages organizer)

Opened from Document Actions **… → Pages**. Preserves the previous thumbnail grid for organization:

- Reorder via drag-and-drop
- Rotate / Duplicate / Delete per card
- Tap a thumbnail to activate that page and dismiss the sheet
- Accessibility identifiers: `documentPagesOrganizer`, `documentPageGrid`, `pageThumbnail_N`, `documentPagesOrganizerDone`

## 7.5 Document search

### Overview

Find text anywhere in the current PDF from **Document Mode** or **Page Mode** using one shared search engine. Search reads the PDF text layer (native vector text or OCR-embedded invisible text from scan-to-PDF). The user does not choose a search source.

Search highlights are **temporary UI only**. They do not create annotations, affect export, appear in thumbnails, or create undo entries.

### Entry points

| Mode | Control | Behaviour |
|------|---------|-----------|
| **Document Mode** | Toolbar **Search** button | Opens search sheet with field and grouped results |
| **Page Mode** | Toolbar **Search** button | Shows inline search bar above the page canvas |

Both entry points search the **entire document**, not only the visible page.

### Search behaviour

- **Incremental:** results update as the user types
- **Case insensitive** and **diacritic insensitive**
- Leading/trailing whitespace in the query is ignored
- Empty query clears results
- Results cache avoids rescanning unchanged documents for the same query

### Document Mode UI

Search sheet contains:

- Search field
- Grouped results by page number, e.g. **Page 2** with bullet rows showing context snippets
- Matched text emphasized in orange within the snippet
- **No results** empty state: *No matches found for “query”.*
- **Close** dismisses search and clears all search highlights

Tapping a result:

1. Closes the search sheet
2. Keeps search active with that match selected
3. Opens Page Mode on the correct page
4. Highlights all matches on the page; active match uses stronger orange emphasis

### Page Mode UI

When search is active, a bar above the canvas shows:

- Search field (same query as Document Mode)
- **Previous match** / **Next match** buttons
- Position label, e.g. **3 of 17**, or **No results**
- **Close** clears search

Previous/Next moves through matches **document-wide**. Crossing a page boundary automatically navigates to the next/previous page and updates the navigation title (**Page N**).

### Highlight appearance

- Inactive matches: light orange fill (~35% opacity)
- Active match: stronger orange fill (~55%) with orange stroke
- Visually distinct from permanent yellow **highlight annotations**

### Interaction with other features

Search coexists with overlays, annotations, PDF text selection, zoom, and page swipe. Opening search clears overlay/annotation selection on the current page. Search survives page navigation and zoom while active.

### Lifecycle

Search state **resets** when:

- User closes search (Close button)
- **New PDF** / session close
- Importing another PDF
- App restart

Search state is **not** stored in undo snapshots.

### Known limitations (V1)

- No search result preview thumbnails
- No regex or whole-word-only options
- Image-only pages without a text layer return no matches
- Search does not run OCR on imported image PDFs at find time (only existing embedded text is searched)

---

## 8. Page reordering

### Gesture

- **Drag** a page thumbnail (long-press and drag — standard iOS drag interaction on the thumbnail card)

### Behaviour

1. User begins drag on a thumbnail → dragged page becomes semi-transparent
2. As the drag enters another thumbnail's drop zone, pages **animate** (0.2 s ease-in-out) to reorder live
3. **One undo entry** is recorded for the entire drag operation (on first movement between positions, not per intermediate slot)
4. On drop: drag state clears

### Limits

- Cannot reorder if only one page (drop still works but has no effect when dropped on self)
- Dropping on the same index: no change

### Undo

- Undo restores the entire page order (and all other snapshot state) from before the drag began

### Page Mode interaction

- Reordering in Document Mode updates which page the user sees when swiping in Page Mode (order follows the grid)

---

## 9. Page rotate, duplicate, delete

### Rotate

- **Button:** Rotate icon below each thumbnail
- **Effect:** rotates that page **90° clockwise** per tap (0° → 90° → 180° → 270° → 0°)
- Overlays on that page **stay in stored positions**; they are re-rendered for the new rotation
- Thumbnail refreshes
- **Undo:** one undo entry per rotate

### Duplicate

- **Button:** Duplicate icon below each thumbnail
- **Effect:** inserts a **copy** of the page **immediately after** the original
- Copy references the **same underlying PDF page** (`originalPageIndex`) and same rotation
- **All overlays** on the source page are copied to the duplicate (same image assets, new overlay IDs)
- **Undo:** one undo entry

### Delete

- **Button:** Trash icon (destructive) below each thumbnail
- **Effect:** removes the page from the document list
- **All overlays** on that page are removed
- **No confirmation dialog**
- **Undo:** one undo entry
- If last page deleted → [empty document state](#empty-document-state-all-pages-deleted)

---

## 10. Document Actions menu

### Entry point

- **⋯** button (ellipsis.circle) in Document Mode toolbar (top-right)
- Accessibility label: **"More"**
- **Disabled** when the document has zero pages

### Menu items (in order)

| Item | Icon | Opens / triggers |
|------|------|------------------|
| **Compress** | arrow.down.doc | Compression sheet |
| **Page Numbers** | number | Page Numbers sheet |
| **Watermark** | drop.degreesign | Watermark sheet |
| **Export** | square.and.arrow.up | Export flow (may show paywall) |

---

## 11. Export

### Entry point

- **Export** in Document Actions menu

### What gets exported

A **new PDF file** built from:

- Current page list and order
- Per-page rotation
- Image, text, and signature overlays
- Applied page numbers (if enabled)
- Applied watermark (text or image, if enabled)
- Page annotations (if any)
- Original PDF page content preserved as vector where possible (searchable text on supported paths)

The exported file name: **`{documentName}-arranged.pdf`** (slashes and colons in the name replaced with hyphens).

### Authoritative write-back (ownership)

| Session ownership | On successful Export generation |
|-------------------|----------------------------------|
| **External** | **No** write-back to the Files original. Only the temp share file is created. |
| **App-owned** | Temp share file is created **and** its bytes are copied over `appOwned/{id}.pdf` **immediately** (before the share sheet). Write-back failures are swallowed silently; share may still proceed. |

### Flow (within free limit)

1. User taps Export (paywall may appear first — see [Paywall](#12-paywall-export-limit))
2. App generates PDF to a **temporary file**
3. If the session is **app-owned**, that temp PDF is written back to the authoritative app-owned file
4. **iOS share sheet** appears with the PDF
5. User can AirDrop, Save to Files, Mail, etc. (for **external** documents, overwriting the original in Files is a **manual** Share destination choice — the app does not do it automatically)
6. When share sheet is dismissed, the **temporary** export file is **deleted** (app-owned authoritative file, if updated in step 3, is **not** rolled back)

### Export failure

- Alert: **"Export Failed"** with message **"Could not export the PDF."** (or other error text)
- **OK** dismisses alert
- User remains in Document Mode; no file is shared
- If generation failed before write-back, app-owned storage is unchanged

### Export with paywall

See [Paywall](#12-paywall-export-limit).

### Cancel / dismiss share sheet

- Dismissing the share sheet without sharing: no error; **temp** export file cleaned up
- **In-editor session state** is unchanged
- **App-owned** authoritative file **remains** at the version written in step 3 if Export generation succeeded (dismissing Share does not undo write-back)

### Repeat export

- Each export generates a **fresh** temporary file
- Reflects **current** document state at time of export
- App-owned write-back runs again on each successful generation

### After app restart

- No export occurs automatically; user must export again
- Reopening Recent: **external** → current Files bytes at bookmark; **app-owned** → last successfully written-back app-owned file

---

## 12. Paywall (export limit)

### When shown

- When the user taps **Export** in Document Actions on a document with **more than 20 pages** and Pro is not unlocked for the session
- **Not** shown for Compression **Save / Share** (that path is currently ungated — see [Known limitations](#29-known-limitations))

### What the user sees

- Sheet with:
  - Icon and title **"Unlock PDF Pages Pro"**
  - Text: **"You're exporting N pages. Free exports are limited to 20 pages."**
  - Benefit list (includes items marked **"coming soon"**)
  - **Continue for now** (prominent button)
  - **Cancel** (toolbar)

### Actions

| Action | Result |
|--------|--------|
| **Continue for now** | Unlocks Pro for **this app session**, dismisses paywall, **export proceeds immediately** |
| **Cancel** | Dismisses paywall; **no export** |

### After app restart

- Pro unlock is **lost**; limit applies again

### Note

This is a **placeholder** paywall for development; there is no real in-app purchase flow in the current product.

---

## 13. Compression

### Entry point

- **Compress** in Document Actions menu

### Compression sheet — configuration screen

**Title:** Compress  
**Close** button (top-left; disabled while compressing)

**On open:**

1. Automatically prepares input by **exporting the current document** (same pipeline as [Export](#11-export), including **app-owned write-back** if the session is app-owned)
2. Shows **"Preparing export preview…"** while preparing
3. Then shows **Current File Size** as a large formatted value (e.g. "2.4 MB")
4. Shows **Estimated** size for the selected preset (approximate)

**Compression Preset** section — three selectable options:

| Preset | Default? | Description shown to user |
|--------|----------|---------------------------|
| **Highest Quality** | No | Preserves all vector content; removes only redundant producer metadata. |
| **Balanced** | **Yes** (labelled "Default") | Recommended balance that keeps text and links while trimming document metadata. |
| **Smallest File** | No | Most aggressive metadata cleanup while keeping pages fully vector. |

- Tap a preset row to select it (highlighted background)
- **Compress PDF** button (prominent; disabled until preparation succeeds)

### While compressing

- Progress bar with percentage: **"Compressing… N%"**
- **Cancel** button — cancels compression task
- **Close** is disabled
- Sheet **cannot be dismissed** by swipe (interactive dismiss disabled)

### Compression failure

- Alert: **"Compression Failed"** with error message
- **OK** dismisses

### Preparation failure

- Size card shows: **"Could not prepare the current document for compression."**
- **Compress PDF** remains disabled

### Result screen

After success:

- Shows original size → arrow → compressed size
- **"N% smaller"** in green
- **Save / Share** — opens share sheet with compressed PDF (**no** 20-page paywall check today)
- **Continue Editing** — **replaces the entire session** by re-importing the compressed PDF; dismisses compression sheet; clears undo/redo
  - If the session was **app-owned**: replaces the **same** app-owned authoritative file, then reopens it
  - If the session was **external** (or ownership unknown): imports the compressed PDF as a **new app-owned** Recent document (original external Recent entry and Files original remain unchanged)

### Close without continuing

- **Close** on configuration or result (when not compressing): dismisses sheet
- Temporary prepared export / share files are cleaned up
- **In-editor session** is unchanged unless the user tapped **Continue Editing**
- If preparation already ran Export for an **app-owned** session, the authoritative app-owned file **may already have been updated** even if the user closes without compressing or continuing

### Cancel during compression

- Stops compression; user returns to configuration screen

---

## 14. Page Numbers

### Entry point

- **Page Numbers** in Document Actions menu

### Sheet layout

**Title:** Page Numbers  
**Close** button (top-left)

**Sections:**

1. **Position** — inline picker, one of:
   - Bottom center (**default**)
   - Bottom right
   - Bottom left
   - Top center
   - Top right
   - Top left

2. **Format** — inline picker, one of:
   - **1** (default)
   - Page 1
   - Page 1 of 10

3. **Start Number** — stepper, range **1…9999**, default **1**

4. **Apply To** — segmented:
   - **All pages** (default)
   - **Selected range**
   - If range: **From page N** and **To page M** steppers (1…page count); range ends auto-adjust if start moves past end

5. **Preview** — shows formatted text for the **last page** in the document (or **"No number on this page"** if last page excluded from range)

6. **Actions:**
   - **Apply Page Numbers** — applies settings and dismisses sheet
   - **Remove Page Numbers** (destructive, red) — only visible if page numbers are currently applied; removes and dismisses

### Defaults (first apply)

| Setting | Default |
|---------|---------|
| Position | Bottom center |
| Format | `1` |
| Start number | 1 |
| Apply to | All pages |

### After Apply

- Page numbers appear on:
  - Document Mode thumbnails (for affected pages)
  - Page Mode preview (for affected pages)
  - Exported PDF (vector text)
- Numbering uses **current document order** (after reorders/deletes)
- Display number on first exported page = start number (for "all pages" mode)
- For range mode: numbering starts at start number on the first page in the range

### Close without Apply

- Changes in the sheet are **discarded**
- Previously applied page numbers (if any) **unchanged**

### Remove Page Numbers

- Clears all page numbers
- **Undo:** one undo entry

### Undo

- Applying or removing page numbers: **one undo entry** each

### Not configurable in UI

- Font size (fixed at 12 pt in product defaults)
- Opacity (fixed at 100%)

---

## 14.5 Document Watermark

### Entry point

- **Watermark** in Document Actions menu

### Sheet layout

**Title:** Watermark  
**Close** button (top-left)

**Sections:**

1. **Watermark Type**
   - Segmented control labeled **Watermark Type** (default **Text**)
   - V1 options: **Text**, **Image**
   - Architecture supports future types (e.g. QR code, PDF page, stamp) without replacing `WatermarkSettings` or `WatermarkGeometryEngine`
   - When **Text** is selected:
     - Watermark string (default **CONFIDENTIAL**)
   - When **Image** is selected:
     - **Choose Image** — Photos picker
     - **Choose from Files** — file importer (image types)
     - **Replace Image** — when an image is already selected
     - **Remove Image** — clears the draft image (destructive)
     - Inline preview of the selected image
2. **Appearance**
   - Opacity slider (**0.1…1.0**, default **0.35**)
   - Size stepper (**5%…80%** of page width, default **35%**; same relative size in thumbnails, Page Mode, and export; image watermarks preserve aspect ratio and are never stretched)
   - Rotation stepper (**−180°…180°**, default **45°**)
   - Color presets (text only): Gray, Black, Blue, Red (default Gray)
   - Position: Center (**default**), Top, Bottom
   - Layer: **Above content** (**default**), Behind content
     - Helper when Behind content is selected: *"Behind content may be hidden by page text, images, or filled backgrounds."*
3. **Apply To**
   - **Entire document** (default)
   - **Current page** — stepper to pick page number
   - **Page range** — from/to steppers
4. **Preview** — rotated sample of the watermark text (text content only)
5. **Actions**
   - **Apply Watermark** — applies and dismisses (disabled if text is empty or no image is selected)
   - **Remove Watermark** (destructive) — only when watermark is active

### Rendering

- Document-level settings stored in session (not page overlays)
- Single `WatermarkSettings` model keyed by **`WatermarkType`** (V1: text, image); shared fields apply to all types
- Type-specific fields: `text` (text type), `imageAssetID` (image type)
- Image bytes stored in the session `imageAssets` dictionary (same storage as overlay images); settings hold only a UUID reference
- **`WatermarkGeometryEngine`** computes normalized position, scale, rotation, and bounds once for every watermark type; text derives font size from render width, image derives height from aspect ratio
- **`WatermarkRenderer`** branches by `watermarkType` — no separate watermark systems per type
- **Text:** vector text in export; raster composited on thumbnails and Page Mode preview
- **Image:** raster watermark image in export (original page content remains vector); raster composited on thumbnails and Page Mode preview via `OverlayGeometryEngine` draw helpers
- **Layer** controls stacking relative to original page content:
  - **Above content** — page vector/text first, then watermark, then manual overlays, then page numbers
  - **Behind content** — watermark first, then page content, then manual overlays, then page numbers
- Manual image/signature overlays and page numbers always render above the watermark
- Occupies the same relative percentage of every page regardless of page size, thumbnail size, Page Mode zoom, or export resolution
- Works with rotated pages and mixed page sizes

### Undo

- Apply, change watermark type, change image, or remove watermark: **one undo entry** each

### Remove Watermark

- Clears watermark settings and orphaned image asset reference
- Does **not** remove signatures, images, page numbers, or original PDF content

---

## 15. Active page editing

Editing happens on the **active page** inside the unified vertical document. The active page uses the existing `PageOverlayCanvasView` overlay/annotation system.

- Double-tap / selection / Add sheet behaviours are unchanged for the active page
- Overlay editing gestures take priority over document scrolling while active
- Keyboard avoidance keeps the active text overlay visible without abandoning scroll position

## 16. Vertical page navigation

Primary navigation is **vertical scrolling**.

| Behaviour | Detail |
|-----------|--------|
| Scroll | Moves through pages in document order |
| Tap page | Activates that page |
| Auto-activate | Primary visible page becomes active while scrolling (blocked during text/drawing/placement) |
| Search / Pages sheet | Programmatically scrolls to and activates the target page |
| Horizontal swipe | Disabled on the unified surface (retained only in non-unified canvas paths) |

## 17. Document zoom and pan

On the **unified vertical document**, magnification is owned by the document surface (`DocumentZoomState`), not by individual pages.

### Pinch zoom

- Pinching **anywhere** on the document (active or inactive page) updates one shared scale
- Every page frame and inter-page gap scales together so pages never overlap
- Range: **1×** (fitted width) to **4×**
- Pinch ends at ≤1× (+ small tolerance): returns to fitted-width layout
- Focal point under the pinch is preserved; switching the active page does **not** reset zoom
- Stored overlay/annotation coordinates stay page-normalized; zoom is display-only

### Pan while magnified

- Above fitted width, the document scrolls freely **horizontally and vertically**
- Vertical page snapping is suppressed while magnified; active-page tracking still follows the viewport
- Returning to fitted width resumes normal settle-snap

### Double tap

- Resets document zoom to fitted width (animated)

### When overlay is selected / editing

- Document pinch still applies to the whole stack unless scroll is blocked by an active editing mode
- User can still pinch a **selected image/signature overlay** to resize it (see [Overlays](#21-overlay-selection-and-manipulation))
- Page-local canvas zoom (`scaleEffect` on one page) is **disabled** on the unified surface

---

## 18. Adding content in Page Mode

### Entry point

- **Add** button in bottom bar

### Add sheet

**Title:** Add  
**Cancel** (top-left)  
**Detent:** medium height, drag indicator visible

| Option | Subtitle | Enabled? | Action |
|--------|----------|----------|--------|
| **Text** | Add editable text | **Yes** | Dismisses sheet → creates an on-page text overlay and enters inline editing (see [Text overlays](#195-text-overlays)) |
| **Image** | Import from Photos or Files | **Yes** | Dismisses sheet → opens **Photos picker** |
| **Draw** | Draw on the page | **Yes** | Dismisses sheet → enters **Drawing Mode** |
| **Sticky Note** | Place a note on the page | **Yes** | Dismisses sheet → arms tap-to-place sticky note |
| **Quick Signature** | Place your default signature | **Yes** | Dismisses sheet → silently arms tap-to-place (see below), or opens **Signature Library** if none is available |
| **Signature Library** | Choose, create, or manage signatures | **Yes** | Dismisses sheet → opens **Signature Library** |

Highlight and Text Comment are **not** in the Add sheet — they require native PDF text selection.

### Text import

See [Text overlays](#195-text-overlays).

### Quick Signature

**Entry:** Add → **Quick Signature**

| Situation | Result |
|-----------|--------|
| **Case A** — User has an explicit **Default Signature** set | Silently arms tap-to-place (see below). Add sheet dismisses; library does **not** open. |
| **Case B** — User has **exactly one** saved signature and **no** explicit Default Signature | Same silent tap-to-place flow as Case A. User is **not** required to mark it as default. |
| **Case C** — User has **multiple** saved signatures and **no** explicit Default Signature | **Signature Library** opens with a guidance banner at the top: *"Choose a default signature for one-tap signing."* User can place any signature, set a Default Signature via the star, or create a new one. |
| **Case D** — User has **no** saved signatures | **Signature Library** opens in the **empty state** (Create Signature). No guidance banner. |

Quick Signature does **not** open the drawing capture screen directly.

### Image import

1. System Photos picker opens (images only)
2. User picks an image
3. If image loads successfully: **image overlay** added centred on page, sheet/picker closes
4. If image fails to load: **nothing happens** (no error shown)

### Signature import

See [Signatures](#20-signatures--library-drawing-placement).

---

## 19.4 Page annotations (V1)

Non-destructive review annotations on imported PDF pages. Stored in app state (`annotationsByPage`), not written to the source PDF until export.

### Types

| Type | Entry | Anchor |
|------|-------|--------|
| **Highlight** | PDF text selection → Highlight | One or more normalized rectangles from selection |
| **Text comment** | PDF text selection → Comment (or Highlight menu → Comment) | Selected text + anchor rectangles |
| **Sticky note** | Add → Sticky Note → tap page | Normalized point on page |
| **Drawing** | Add → Draw → Drawing Mode | Multiple strokes of normalized points |

Sticky notes and text comments are **separate workflows** (point anchor vs text-anchored comment).

### Highlights

- Default: **yellow**, ~**35%** opacity, rendered behind readable text
- Tap highlight → contextual menu: color presets (yellow, green, blue, pink, orange), Comment, Delete
- Color change and delete each create one undo entry
- Appears in Page Mode, Document Mode thumbnails, and export

### Text comments

- Editor shows selected-text preview, multiline comment field, Cancel / Add (or Save when editing)
- Empty or whitespace-only comments are rejected with feedback
- Visible anchor: light underline/highlight on selected text + small comment marker
- Tap marker → popover with comment text, Edit, Delete

### Sticky notes

- Add → Sticky Note dismisses sheet and arms placement; next tap **inside** the page sets position (tap outside cancels)
- Compact note editor requires non-empty text
- Collapsed marker icon on page; tap → popover with note text, Edit, Delete
- **Move:** drag marker while selected; one undo entry when drag ends; position clamped to page bounds

### Drawing Mode

- Explicit mode with bottom toolbar: pen color (black, red, blue, green, yellow), thickness (thin / medium / thick), eraser, undo last stroke, clear session, Done
- Last-used color and thickness persist in UserDefaults across sessions
- Finger and Apple Pencil both draw; points stored normalized to unrotated page
- Page swipe, zoom, pan, overlay manipulation, and PDF text selection disabled while active
- **Undo last stroke** affects current session only (not global undo stack)
- **Done** commits all session strokes as one drawing annotation → one global undo entry
- **Eraser (V1):** removes entire stroke on intersection (not pixel erasing)
- **Clear** removes uncommitted session strokes only (no global undo)
- Completed drawing: tap to select → Delete only (**Edit/re-enter Drawing Mode is not implemented in V1**)

### Page operations

- **Duplicate page** copies all annotations with new IDs
- **Delete page** removes annotations with the page (undo restores)
- **Rotate page** keeps stored normalized coordinates unchanged; rendering adapts

### Export stacking order

1. Behind-content watermark  
2. Original PDF vector page  
3. Highlights  
4. Drawings  
5. Text-comment anchor styling  
6. Sticky-note markers  
7. Above-content watermark  
8. Image/signature overlays  
9. Page numbers  

### Known limitations (V1)

- No drawing edit-in-place after Done (delete and re-draw)
- No cloud comments, threads, or collaboration
- No pressure sensitivity, shape tools, underline, or strikethrough
- No import of third-party PDF annotation objects beyond what remains in the source file

---

## 19. Image overlays

### Creation

- From **Add → Image**
- Placed at **centre** of page
- Initial width: **35%** of page width (height from image aspect ratio, capped)
- **Placement feedback:** light haptic + short scale/fade “stamp” animation (see [Overlay placement feedback](#overlay-placement-feedback))
- **Undo:** one entry

### Appearance

- Raster image scaled to fit overlay bounds
- Default opacity: **100%**

### In Document Mode

- Shown composited on thumbnail

### In export

- Drawn as image on top of vector PDF page content

---

## 19.5 Text overlays

Editable text boxes placed on individual pages in Page Mode. Text is stored as overlay data and exported as **vector text** drawn above page content. Creation and editing happen **directly on the page** (Freeform-style compact formatting bar), not in a separate entry sheet.

### Creation flow

1. **Add → Text**
2. A new text overlay is created at a sensible visible position on the current page
3. The overlay is **selected immediately** and enters **inline editing** with the keyboard focused
4. Placeholder hint **"Text"** is shown only while the body is empty — it is **never** saved, persisted, added to Recent Texts, rendered in thumbnails, or exported
5. As the user types, the box **grows vertically** to fit wrapped multiline content while preserving any manual width the user set
6. The page viewport shifts when needed so the active overlay stays visible above the keyboard
7. **Done** on the format bar, or tapping outside the overlay, finishes editing
8. If the new overlay is still empty when editing ends, it is **discarded** (no empty object left behind; no undo entry for the cancelled draft)

### Formatting bar (above keyboard)

While editing, a **Freeform-style compact bar** sits above the keyboard. It keeps the active text and caret visible and does **not** expose every formatting control at once. The floating page chrome (capsule toolbar and circular **Add** button) is hidden for the duration of text editing. Object chrome (move, resize, rotate, duplicate, delete) stays outside this typing toolbar.

The compact bar shows five progressive-disclosure controls plus **Done**. Tapping a control opens a **focused menu panel** above the bar (only one at a time):

| Control | Opens | Contents |
|---------|-------|----------|
| **Aa** | Appearance menu | Font family (System / Serif / Mono), font size **8–72 pt**, text color, overlay opacity **5–100%** |
| **BIU** | Style menu | Bold, italic, underline, strikethrough |
| **Alignment** | Alignment menu | Left / Centre / Right |
| **Lists** | Lists menu | None / Bulleted / Numbered / Dashed, increase/decrease indent |
| **…** | More menu | Insert Date, Recent Texts, Duplicate, Reset Formatting |
| **Done** | — | Commits editing (or discards empty new drafts) |

Rules:

- **Only one** focused menu (or the Recent Texts sheet) may be open at a time
- Menus dismiss when editing ends (Done, tap outside, or session teardown)
- Font, size, color, and style changes apply to the **selected range**, or to typing defaults / whole-overlay attributes when nothing is selected
- Opacity, alignment, and list/indent apply to the whole overlay
- All changes update the on-page overlay **live**
- **Recent Texts:** up to **10** previously committed texts; tap to insert; swipe to remove
- **Insert Date:** opens a compact date picker (defaults to today, with a **Today** shortcut); inserts the selected date at the caret (or replaces the selection) using the app’s medium date format and current typing attributes
- **Duplicate** (from More): duplicates the overlay being edited (object-level duplicate remains on the selection contextual menu when not typing)
- **Reset Formatting:** restores default styles while preserving the current text body

### Lists while editing

Bulleted, numbered, and dashed list markers render **identically** while typing, when not editing, in thumbnails, after reopen, and on export. Markers stay visible on empty list rows. Return creates the next list item; backspace at the start of an empty item removes it. Indentation and rich-text formatting inside list items are preserved.

Object-level move, resize, rotate, and delete remain available via selection chrome outside the typing toolbar when appropriate; they are not part of the compact formatting bar.

### Rich text

A single text overlay can contain **multiple differently formatted ranges** (font, size, color, bold, italic, underline, strikethrough). Formatting is stored as contiguous `textSpans` on `PageObject` while whole-overlay defaults remain for typing attributes and plain-text compatibility. Existing overlays without spans continue to render with whole-overlay style only.

Committed text (on successful finish with non-empty content) is added to **Recent Texts** (UserDefaults; survives app restart). Overlay objects themselves remain session-scoped until export (same as other overlays).

### Editing existing text

| Entry | Result |
|-------|--------|
| **Double-tap** text overlay | Re-enters on-page inline editing |
| Context menu **Edit** | Same |
| Finish editing | Commits text + formatting as one undoable change |

### Text overlay on page (after editing)

- Blue selection border when selected
- **Resize handle** (bottom-right) — non-uniform resize (width and height adjust independently)
- **Rotate handle** (top-left, orange) — drag to rotate overlay
- **Floating contextual menu:** **Edit** · **Duplicate** · **Delete**
- Text always renders **above** page content (including in export)
- **Undo:** creation (committed), text/formatting commits, move, resize, rotate, duplicate, delete

### In Document Mode

- Shown composited on thumbnail (empty/placeholder drafts are not drawn)

### In export

- Drawn as vector text via `TextOverlayRenderer` on top of page content (placeholder never exported)

### Not supported

- Arbitrary custom font files (built-in System / Serif / Mono families only)
- Per-glyph color alpha separate from overlay opacity (overlay opacity is supported)
- Reflow editing inside the PDF's native text layer (overlays only)
- Multi-select overlay position alignment / distribute tools

---

## 20. Signatures — library, drawing, placement

### Quick Signature

See [Adding content in Page Mode — Quick Signature](#quick-signature). Uses the on-device signature library’s default (or the lone saved signature when applicable).

### Signature library

**Entry:** Add → **Signature Library** in Page Mode (also opened automatically by Quick Signature when no usable default exists)

**Sheet:** large detent, drag indicator

**Empty state:**

- Signature icon, **"No saved signatures"**
- **Create Signature** button

**With saved signatures:**

- **Guidance banner** (only when opened via Quick Signature with multiple signatures and no Default Signature): *"Choose a default signature for one-tap signing."*
- **Create New Signature** button at top
- Grid (2 columns) of saved signatures with name labels
- **Star button** (top-right of each tile) — tap to set that signature as **Default Signature** (see [Default Signature](#default-signature))
- Tap a signature tile (thumbnail area) → silently arms tap-to-place on the current page, **dismisses library**

**Default Signature visual state** (updates **immediately** when the star is tapped — no need to close and reopen the library):

- Filled **yellow star** on the tile
- Accent-colour border around the thumbnail
- **"Default Signature"** badge beside the name label
- Previous Default Signature loses its star and badge at once

**Toolbar:** **Cancel** — dismisses without placing

**Context menu** (system long-press on a signature tile):

- **Rename** — alert with text field; **Save** / **Cancel**
- **Delete** — deletes immediately (no confirmation). If the deleted signature was the default, the default is **cleared**.

**Rename failure** (e.g. empty name): rename silently fails; list unchanged

### Default Signature

- Only **one** signature can be the Default Signature at a time
- Set by tapping the **star** on a library tile (not via long-press menu)
- Tapping a different star **replaces** the previous Default Signature **immediately** in the UI, then persists to storage
- If saving the Default Signature fails, the UI **reverts** and an alert is shown
- Default preference is **persisted** across app launches (`library-preferences.json` in the signature library folder)
- Quick Signature uses the stored Default Signature when set (Case A)
- If there is **exactly one** saved signature and **no** explicit Default Signature, Quick Signature still silently arms tap-to-place (Case B; star/badge remain unset until the user taps the star)

### Signature Placement Mode

**Entry:** Quick Signature (Cases A/B), tap a signature in **Signature Library**, or **Save & Use** after creating a signature

**Behaviour (invisible — no banner, helper text, toast, Cancel, or other placement chrome):**

1. Add / library / capture sheets dismiss; the PDF page stays visible with normal toolbar and **Add** bar
2. Placement is **silently armed** — the next tap **inside the displayed PDF page** places the signature centered on that tap (clamped to page bounds)
3. Tapping **outside** the displayed PDF page does not place anything and clears the armed state
4. While armed: PDF text selection and overlay selection are **disabled**; placement taps take priority
5. Placement uses the standard haptic + scale/fade animation; the new signature is **auto-selected**
6. Armed state ends after a successful page tap, an outside-page tap, opening **Add**, or navigating to another page

**Save & Use** from signature capture saves to the library, then silently arms placement (does not place at center immediately).

### Signature capture (drawing)

**Entry:** Create Signature / Create New Signature (from Signature Library)

**What the user sees:**

- Instruction: **"Draw your signature with your finger."**
- White drawing canvas with border
- **Thickness** row: three options — **Thin**, **Medium** (default), **Thick** — each shown as a labelled sample stroke; selected option has accent border and checkmark
- **Color** row: horizontal scroll of color swatches — Black (default), Dark Gray, Blue, Red, Green, Purple
- **Clear** — erases drawing
- **Cancel** — dismisses without saving
- **Save & Use** — disabled until user has drawn something

**Drawing input:**

- Finger or Apple Pencil (`anyInput` policy)
- Pen tool with selected **color** and **thickness**:
  - **Thin:** ~1.5 pt
  - **Medium:** ~2.5 pt (default)
  - **Thick:** ~4.0 pt
- Changing color or thickness updates the active tool **immediately** and does **not** clear the current drawing
- Canvas always **white background** (light appearance forced)

**Thickness persistence:**

- Last selected thickness is **remembered** across capture sessions and app restarts
- New capture opens with the last used thickness (default **Medium** on first launch)

**Save & Use:**

1. Renders drawing to image (tight crop)
2. Saves PNG to **on-device signature library** (persistent), including optional **stroke thickness metadata** on newly created assets
3. Silently arms tap-to-place on the current PDF page (see above)
4. Dismisses capture and library sheets

### Signature on page

- Treated as an overlay of type **signature**
- Initial width: **30%** of page width (slightly smaller than images)
- Initial height: derived from the saved PNG aspect ratio so the overlay frame matches the signature image (`height = width × imageHeight / imageWidth` on the page); no vertical letterboxing inside the frame
- Same move/resize/delete behaviour as image overlays
- When placed from Quick Signature, Signature Library, or Save & Use (after tap), the new overlay is **selected automatically**

### Signature library persistence

- Stored in app Application Support (`SignatureLibrary/`)
- **Survives app restart**
- **Separate** from per-document overlay image assets (library is reusable across documents and sessions)
- Metadata file: `signatures.json` (signature list)
- Preferences file: `library-preferences.json` (default signature ID)
- New signatures may include optional `strokeThickness` in metadata; **older saved signatures without this field still load normally**
- Last capture **ink thickness** preference is stored separately in app settings (`UserDefaults`), not per signature asset

---

## 21. Overlay selection and manipulation

Applies to **image overlays**, **text overlays**, and **signature overlays**. Image overlays use inline chrome; **selected text and signature overlays** use a floating contextual menu instead of the inline delete (×) control.

### Selection

| Action | Result |
|--------|--------|
| **Tap image overlay** (not selected) | Selects overlay; shows blue border, delete (×) top-right, resize handle bottom-right; brings overlay to **front** if it was behind another |
| **Tap text overlay** (not selected) | Selects overlay; shows blue border, resize handle bottom-right, rotate handle top-left, floating contextual menu (Edit, Duplicate, Delete); brings overlay to **front** if it was behind another |
| **Tap signature overlay** (not selected) | Selects overlay; shows blue border, resize handle bottom-right, and floating contextual menu (Edit, Delete, More); brings overlay to **front** if it was behind another |
| **Tap empty canvas** | Deselects |
| **Select another overlay** | Switches selection |
| **Place overlay** (image import at center, or signature after tap in Placement Mode) | New overlay is **auto-selected** with placement haptic + animation |

**Only one overlay selected at a time.** No multi-select.

### Signature contextual menu

When a **signature overlay** is selected (and the user is not dragging/resizing it, and Signature Placement Mode is off):

| Control | Behaviour |
|---------|-----------|
| **Edit** (pencil icon) | Opens a **floating edit popover** anchored near the signature (placed signature only — not the library asset) |
| **Delete** (trash icon) | Deletes the selected signature overlay (undo supported) |
| **More** (… icon) | **Reset** and **Save to Library** when appearance differs from baseline; plus placeholder items (Duplicate, Replace Signature, layer order — disabled for now) |

The menu is positioned above the signature, clamped within the visible page area. It **hides** while the signature is being moved or resized, while the edit popover is open, and when selection is cleared, another object is selected, PDF text is selected, the Add sheet opens, or Signature Placement Mode starts.

### Edit placed signature

Editing affects **only the selected placement** on the current page. The saved library signature is never modified in place. The document stays in focus — there is **no bottom sheet**, modal, or dimmed background.

**Floating popover** (two compact rows, anchored above or below the signature depending on available space):

| Row | Controls |
|-----|----------|
| **Row 1** | Preset colors: Black, Gray, Blue, Red, Green, Purple — live recolor |
| **Row 2** | Advanced color (palette icon), thickness −, integer **pt** value, thickness + |

| Control | Behaviour |
|---------|-----------|
| **Advanced color** (palette icon) | Presents Apple's native **UIColorPickerViewController**; live recolor with alpha preserved |
| **Thickness − / value / +** | Adjusts stroke width in **whole points** from **2 pt** to **30 pt** (±1 pt per tap); live update |

Changes apply **immediately** — no Apply or Done button. Tap outside, select another overlay, delete the signature, or navigate away to dismiss.

| More menu action | Behaviour |
|------------------|-----------|
| **Reset** | Shown only when appearance differs from original placement; restores baseline color and thickness |
| **Save to Library** | Shown only when appearance differs **and** placement came from the library; creates a **new** library signature without overwriting the original |

Image overlays are unchanged: inline × delete and toolbar **Delete** remain available.

### Text contextual menu

When a **text overlay** is selected (and the user is not dragging/resizing/rotating it, and inline text editing is not active):

| Control | Behaviour |
|---------|-----------|
| **Edit** (pencil icon) | Re-enters on-page inline editing |
| **Duplicate** (plus.square.on.square icon) | Creates a copy offset from the original (**undo** supported) |
| **Delete** (trash icon) | Deletes the selected text overlay (**undo** supported) |

The menu is positioned above the text overlay, clamped within the visible page area. It **hides** while the overlay is being manipulated, while inline text editing is active, when selection is cleared, when PDF text is selected, when the Add sheet opens, or when signature placement mode starts.

### Overlay placement feedback

When the user **newly places** an image, text, or signature overlay in Page Mode (image import, text placement, Quick Signature, Signature Library, or Save & Use):

| Feedback | Behaviour |
|----------|-----------|
| **Haptic** | Light impact haptic fires once on successful placement |
| **Animation** | Overlay fades in (opacity 0 → 1) and scales up (~0.95 → 1.0) over ~150 ms |
| **Selection** | New overlay remains **auto-selected** after the animation |

**Animation does not run** for overlays that already exist when:

- Reopening Page Mode or returning from Document Mode
- Swiping between pages
- Page zoom/pan or normal canvas rendering
- Thumbnail rendering, export, undo/redo, or page duplicate

Haptics do **not** fire for those cases either.

### Move (selected overlay)

- **Drag** anywhere on the overlay
- Overlay follows finger in real time
- On release: position saved, clamped so centre stays within page bounds (0–1 normalized)
- **Undo:** one entry per completed drag
- **Blocks page swipe** while dragging

### Resize — drag handle

- Blue circle handle at bottom-right (only when selected)
- **Image and signature overlays:** drag handle to resize **uniformly** (aspect ratio preserved); size clamped between **8%** and **95%** of page dimension
- **Text overlays:** drag handle to resize **width and height independently** (non-uniform); clamped to layout min/max fractions
- **Undo:** one entry per completed resize
- Uses **high-priority gesture** so page navigation does not interfere
- **Blocks page swipe** while resizing

### Resize — pinch

- **Pinch** on selected **image or signature** overlay to scale uniformly
- Same size limits as handle resize for image/signature
- Text overlays do **not** support pinch resize in V1
- **Undo:** one entry per completed pinch
- **Blocks page swipe** while pinching

### Delete

Four ways:

1. Red **×** button on **image** overlays (top-right when selected)
2. **Delete** in Page Mode toolbar (when any overlay selected)
3. **Delete** (trash icon) in the **signature contextual menu** (signature overlays only)
4. **Delete** (trash icon) in the **text contextual menu** (text overlays only)

All create **undo** entries.

### Z-order

- Tapping an overlay brings it to front (updates z-index)
- If already frontmost: **no undo entry**

### Overlay rotation (object rotation)

| Overlay type | User rotation |
|--------------|---------------|
| **Text** | **Yes** — orange rotate handle (top-left when selected) |
| **Image** | **No** user gesture (data model supports rotation) |
| **Signature** | **No** user gesture (data model supports rotation) |

### Opacity

- Fixed at 100% in current UI (not user-adjustable)

---

## 22. Gesture reference (complete)

### Home / empty state

| Gesture | Target | Effect |
|---------|--------|--------|
| Tap | Open Document | Open file picker |
| Tap | Create Document | Create blank PDF |
| Tap | Recent document row | Open that PDF |
| Tap | More | Show all recent documents |
| Tap | Scan Document | Open scan-to-PDF flow (camera) |
| Tap | Import Photos | Open scan-to-PDF flow (photos) |
| Tap | Settings | Open settings |

### Document Mode

| Gesture | Target | Effect |
|---------|--------|--------|
| Tap | Thumbnail | Open Page Mode |
| Tap | Rotate / Duplicate / Delete | Page action |
| Tap | New PDF / Undo / Redo / ⋯ menu | Toolbar actions |
| **Drag** | Thumbnail | Reorder pages |
| **Scroll** | Grid | Scroll document |

### Unified document — canvas

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Empty canvas | Deselect overlay |
| **Double tap** | Document | Reset document zoom to fitted width |
| **Pinch** | Document (any page) | Zoom entire document 1×–4× |
| **Drag / scroll** | Document (magnified) | Pan horizontally and vertically |
| **Vertical scroll** | Document (fitted width) | Free scroll; settle-snap on idle |
| **Swipe left/right** | — | Disabled on the unified surface |

### Page Mode — overlay (selected)

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Overlay (unselected) | Select |
| **Drag** | Overlay | Move |
| **Drag** | Resize handle | Resize |
| **Pinch** | Overlay | Resize |
| **Tap** | × button (image overlay) | Delete image overlay |
| **Tap** | Signature menu trash icon | Delete signature overlay |

### Page Mode — overlay (unselected)

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Overlay | Select only (no drag until selected) |

### Signature library

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Signature tile (thumbnail) | Use on page |
| **Tap** | Star button on tile | Set as Default Signature (immediate UI update) |
| **Long press** | Signature tile | Context menu (Rename / Delete) |

### Signature capture

| Gesture | Target | Effect |
|---------|--------|--------|
| **Draw** | Canvas | Ink strokes |
| Tap | Thickness option (Thin / Medium / Thick) | Change stroke width (does not clear drawing) |
| Tap | Color swatch | Change ink color (does not clear drawing) |
| Tap | Clear / Cancel / Save & Use | Actions |

### Sheets generally

| Gesture | Effect |
|---------|--------|
| **Swipe down** | Dismiss sheet (unless disabled, e.g. during compression) |

### Not used anywhere

- **Long press** (except signature library context menu via system long-press)
- **Keyboard shortcuts** (none implemented)
- **Multi-finger gestures** beyond standard pinch

---

## 23. Gesture priorities and conflicts

**Priority (highest to lowest):**

1. **Active placement mode** (signature, text, sticky note)
2. **Drawing Mode** (draw / eraser)
3. **Selected annotation** (tap, sticky-note drag)
4. **Overlay resize handle drag** (`highPriorityGesture`) — always wins on handle
5. **Overlay drag / pinch** (when selected) — blocks page navigation while active
6. **Overlay tap** — select
7. **Native PDF text selection** (long-press to mount layer)
8. **Document pinch zoom** (unified surface; not blocked solely by idle overlay selection)
9. **Document scroll / settle-snap** (snap only at fitted-width zoom)
10. **Canvas tap** — deselect

**Specific rules:**

| Situation | Page swipe | Document zoom | Overlay edit |
|-----------|------------|---------------|--------------|
| Drawing Mode active | ❌ Blocked | ❌ Scroll blocked | ❌ Disabled |
| Sticky-note placement armed | ❌ Blocked | ❌ Scroll blocked | ❌ Disabled |
| Selected sticky note being dragged | ❌ Blocked | ❌ Scroll blocked | ❌ Disabled |
| Overlay being dragged | ❌ Blocked | N/A | ✅ Active |
| Overlay being resized (handle or pinch) | ❌ Blocked | N/A | ✅ Active |
| Overlay selected, idle | ❌ (unified) | ✅ Document pinch | ✅ Tap to edit |
| Document magnified | ❌ (unified) | ✅ Pan via scroll | ✅ Select / edit |
| Nothing selected, fitted width | ❌ (unified) | ✅ Pinch | — |

**Intentional design:** Overlay editing takes precedence during active manipulation. On the unified surface, magnification is document-owned; horizontal page swipe is not used for navigation.

---

## 24. Undo and Redo

### Shared document-session history

Document Mode and Page Mode use **one** undo stack and **one** redo stack for the active document session. Actions performed in either mode participate in the same history.

### Entry points

**Document Mode toolbar (leading, after New PDF):**

- **Undo** — `arrow.uturn.backward` icon; accessibility identifier `undoButton`
- **Redo** — `arrow.uturn.forward` icon; accessibility identifier `redoButton`

**Page Mode toolbar (leading, after Search):**

- **Undo** — accessibility identifier `pageModeUndoButton`
- **Redo** — accessibility identifier `pageModeRedoButton`

Undo and Redo remain visible even when an overlay or annotation is selected. Enabled/disabled state always reflects the shared stacks (not the current selection).

### Enabled and disabled states

| Control | Enabled when |
|---------|----------------|
| **Undo** | Undo stack is not empty |
| **Redo** | Redo stack is not empty |

Both are disabled after import until the first undoable edit.

### Animation

- Undo and Redo run with SwiftUI **animation** in both modes.

### Semantics

| User action | History behaviour |
|-------------|-------------------|
| New undoable edit | Push pre-edit snapshot onto undo stack; **clear redo stack** |
| **Undo** | Push current state onto redo stack; restore latest undo snapshot |
| **Redo** | Push current state onto undo stack; restore latest redo snapshot |

Example: rotate a page, undo (redo becomes available), then add a sticky note instead of redo — **redo history is cleared**.

### What snapshots restore

Single snapshot of all editable document state:

- Page list (order, rotations, which pages exist)
- All overlays on all pages (including z-order and appearance)
- All annotations on all pages
- Overlay image assets in memory
- Page number settings
- Watermark settings and watermark image asset references

Temporary UI state is **not** restored: selection, search query, zoom/pan, open sheets, placement modes, uncommitted drawing strokes.

### Page Mode after Undo or Redo

- If the current page still exists, remain on it.
- If the current page was deleted by the restored state, navigate to the nearest valid page index.
- If no pages remain, exit Page Mode to Document Mode empty-document state.
- If the selected overlay or annotation no longer exists, selection and contextual UI are cleared (no auto-replacement).
- Restored objects reappear on the canvas but are not auto-selected.

### Actions that push undo (one entry each, all support Redo)

- Page delete, rotate, duplicate, reorder (entire drag)
- Add / edit / move / resize / rotate / duplicate / delete overlay (image, text, signature)
- Signature appearance changes on a placed signature (committed when control interaction ends)
- Add / change color / delete highlight
- Add / edit / delete text comment
- Add / edit / move / delete sticky note
- Add / delete drawing annotation (one completed Drawing Mode session)
- Bring overlay to front (only if z-order actually changes)
- Apply / change / remove page numbers
- Apply / change / remove watermark (text or image)

### Grouped gesture behaviour

- Page reorder: one entry when drag completes
- Overlay move / resize / sticky-note move: one entry on gesture end
- Drawing Mode: one entry when user taps **Done** (`Undo Last Stroke` inside Drawing Mode is local to the uncommitted session only)
- Continuous sliders / color pickers: one entry when the editor is dismissed (not per intermediate value)

### Actions that do NOT push undo

- Navigating in Page Mode (swipe between pages)
- Opening/closing sheets (except committed edits inside them)
- Importing / New PDF (clears **both** stacks)
- Export / share
- Compression preview alone; **Continue Editing** re-import clears both stacks
- Changing appearance settings
- Selecting/deselecting without editing
- Searching or navigating search matches
- Zooming/panning page in Page Mode
- Undo / Redo themselves (beyond stack movement)

### History limit

- Maximum **50** steps on **each** of undo and redo; oldest entries dropped

### Repeat undo / redo

- Each tap moves **one** step through the respective stack

### After app restart

- Undo and redo history are **empty** (not persisted)

---

## 25. Empty, loading, and error states

| Context | State | What user sees |
|---------|-------|----------------|
| No document | Empty home | PDF Pages title, Recent Documents, Open Document / Create Document / Scan to PDF / Photo to PDF |
| All pages deleted | Empty document | "No Pages" + hint to import |
| Importing | Loading overlay | Dimmed screen + "Importing PDF…" |
| Import failed | Alert | "Import Failed" + message |
| Thumbnail loading | Inline spinner | ProgressView in thumbnail frame |
| Page Mode loading | Inline spinner | "Loading page…" |
| Compression preparing | Inline spinner | "Preparing export preview…" |
| Compression running | Progress bar | Percentage + Cancel |
| Compression failed | Alert | "Compression Failed" |
| Export failed | Alert | "Export Failed" |
| Signature library empty | Empty state | Icon + Create Signature |
| Paywall | Sheet | Pro messaging |

---

## 26. Accessibility

### Implemented

- Many controls have `accessibilityIdentifier`s for UI testing (import button, settings, thumbnails, overlays, compression, export, etc.)
- Unified document editor: `documentModeReady` (session surface), `unifiedDocumentScroll`, `documentPageSlot_N`, `pageModeView` with `accessibilityValue` **"page N of M"**, `pageBottomToolbar` (floating chrome container), `floatingPageToolbar`, `pageModeAddButton`, `pageToolbarRotate` / `pageToolbarDuplicate` / `pageToolbarDelete`
- Pages organizer: `documentPagesOrganizer`, `documentPageGrid`, `pageThumbnail_N`, `documentPagesOrganizerDone`
- Settings gear: accessibility label **"Settings"**
- Document Actions: accessibility label **"More"**; identifier `documentActionsButton`
- Unified editor Undo / Redo: accessibility labels **"Undo"** / **"Redo"**; identifiers `undoButton`, `redoButton`
- Thumbnail action buttons (organizer): accessibility labels **"Rotate"**, **"Duplicate"**, **"Delete"**
- Overlay delete button: **"Delete image"** (image overlays only)
- Signature contextual menu: **"Edit Signature"**, **"Delete Signature"**, **"More Signature Actions"**
- Edit placed signature popover: `placedSignatureEditPopover`, `signatureEditAdvancedColorButton`, `signatureEditThicknessMinus`, `signatureEditThicknessValue`, `signatureEditThicknessPlus`, per-preset color identifiers
- More menu: `signatureMenuReset`, `signatureMenuSaveToLibrary`
- Signature color swatches: per-color accessibility labels/identifiers
- Signature thickness options: per-thickness accessibility labels/identifiers (`signatureThickness_thin`, etc.)
- Signature library default star buttons: per-signature accessibility identifiers
- Add menu: `addQuickSignatureOption`, `addSignatureLibraryOption`
- Decorative icons on empty states: `accessibilityHidden(true)` where applied

### Not specially implemented

- No custom VoiceOver hints for gestures (swipe between pages, pinch zoom, etc.)
- No reduced-motion-specific alternatives documented in code

---

## 27. Persistence and app restart

| Data | Persists across restart? |
|------|--------------------------|
| Appearance setting (Device/Light/Dark) | **Yes** |
| **Make PDF Searchable** (scan-to-PDF; Draft Review toggle) | **Yes** |
| **Recent Texts** (text overlay editor) | **Yes** |
| **Recent Documents** (index: bookmarks / app-owned refs; schema v2) | **Yes** |
| Signature library (saved signatures) | **Yes** |
| Default / favorite signature | **Yes** |
| Last signature ink thickness (capture UI) | **Yes** |
| Drawing annotation color / thickness | **Yes** |
| Open document / pages / overlays / annotations | **No** |
| Scan draft session | **No** |
| Undo / redo history | **No** |
| Page number settings | **No** |
| Watermark settings | **No** |
| Pro unlock | **No** |
| Import / export temp files | **No** (current session temp cleaned on New PDF / close; orphans under `PDFImports/` may linger after force-quit until OS temp cleanup) |

After restart: user sees **home screen** with **Recent Documents** (if any). Acquisition actions (**Open Document**, **Create Document**, **Scan to PDF**, **Photo to PDF**) remain available; **Open In…** works when another app sends a PDF. Saved signatures, default signature, last ink thickness, drawing prefs, Recent Texts, Recent Documents, and Make PDF Searchable preference remain available.

**Legacy Recent index:** schema v1 (content-fingerprint library under `files/`) is incompatible. On load, a non–schema-v2 index is ignored (empty Recent). The legacy `files/` directory is deleted when present. Users may see an empty Recent list until they open documents again.

---

## 28. Limits and defaults

| Item | Value |
|------|-------|
| Free **Export** page limit (Document Actions → Export only) | **20 pages** |
| Undo stack depth | **50** |
| Redo stack depth | **50** |
| Document zoom max | **4×** |
| Overlay min size | **8%** of page |
| Overlay max size | **95%** of page |
| Image overlay initial width | **35%** of page width |
| Signature overlay initial width | **30%** of page width |
| Page swipe min distance | **~60 pt** |
| Page numbers start number range | **1–9999** |
| Page numbers default font size | **12 pt** (not exposed in UI) |
| Compression default preset | **Balanced** |
| Appearance default | **Device** |
| Signature ink default color | **Black** |
| Signature ink default thickness | **Medium** (~2.5 pt) |
| Signature ink thickness options | **Thin** ~1.5 pt, **Medium** ~2.5 pt, **Thick** ~4.0 pt |
| Overlay placement animation duration | **~150 ms** |
| Overlay placement animation scale | **0.95 → 1.0** |
| PDF import | **Single file**, PDF only |
| Photos import (scan-to-PDF) | **Up to 50** images per pick |
| Text overlay font size | **8–72 pt** (default **14 pt**) |
| Recent Texts storage | **10** entries max |
| Recent Documents home preview | **5** entries |
| Recent Documents max stored | **50** entries |
| Make PDF Searchable (scan-to-PDF) | **On** by default |
| Multi-page selection | **Not supported** (editor; scan review supports batch selection for delete/apply) |

---

## 29. Known limitations

1. **No session persistence** — closing the app loses in-progress editor edits unless Export / Compress prep already wrote an **app-owned** authoritative file, or the user manually saved an **external** export over the Files original. Recent reopens the authoritative location (bookmark or app-owned), not a hostage library of external PDFs.
2. **External Export does not update Files** — Export only shares a temp copy; Recent reopen of an external document can show the **pre-edit** Files version if the user did not overwrite that file via Share.
3. **App-owned write-back is immediate** — successful Export generation (and Compress preparation) overwrites `appOwned/{id}.pdf` even if the user dismisses the share sheet or closes Compress without continuing. Write-back failures are silent.
4. **Paywall is Export-only** — Compression **Save / Share** does **not** enforce the 20-page free limit.
5. **Paywall is a placeholder** — "Continue for now" unlocks Pro for the session only; no real purchase.
6. **Paywall lists "coming soon" features** (merge & split, batch tools) that are not in the app.
7. **No split, merge, password protect** in Document Actions (future only). Watermark is implemented.
8. **OCR is scan-to-PDF only** — imported PDFs are not re-OCR'd in the editor.
9. **Text overlays** — System / Serif / Mono families; selection-aware rich text + overlay opacity; not native PDF text reflow; editing is on-page (not a separate entry sheet).
10. **Page number font size and opacity** — not user-configurable in UI.
11. **Image/signature overlay rotation** — not user-configurable in UI (text overlays support rotate).
12. **No multi-select** for pages or overlays in the editor (scan review supports batch page selection).
13. **Deleting a page** — no confirmation dialog.
14. **New PDF** — no confirmation; immediate session loss.
15. **Image import failure** — silent (no error if photo data invalid).
16. **Signature rename failure** — silent (no error alert).
17. **Compression "Continue Editing"** replaces the entire session and clears undo and redo; for **external** sessions it also creates a **new app-owned** Recent entry (original Files document unchanged).
18. **Document name** in title comes from imported file name (or **Scanned Document** for scan handoff); user cannot rename in app.
19. **Thumbnail position badge** (1, 2, 3…) is always list position; it is independent of page-number feature formatting unless values coincide.
20. **Page Numbers preview** in setup sheet always reflects the **last page** in the document, not the page currently being edited in Page Mode.
21. **Scan draft sessions** do not resume after app restart.
22. **No visible undo history panel** — only step-by-step Undo and Redo buttons.
23. **No user delete on Recent Documents** — entries are pruned only when missing/unresolvable or when the store exceeds 50 (evicted app-owned PDFs are deleted).
24. **Open In declares in-place support** but editing always uses a sandbox temp copy.

## 30. Features not implemented

The following are **not** available in the current product (do not test for them):

- Save project / reopen project (beyond Recent Documents index)
- Share Extension target (Open In… is supported; Share Extension should call the same `handleIncomingDocumentURL` / `importPDF` path when added)
- Multiple open documents
- Drafts on Home (architecture reserved; not implemented)
- OCR on imported PDFs (scan-to-PDF OCR is implemented)
- Split / merge PDFs
- Password protect PDF
- Document rename
- Document information panel
- Batch tools
- Real in-app purchase / subscription
- Multi-selection (pages or overlays)
- Keyboard shortcuts
- Apple Pencil-only mode for signatures (Pencil works, but finger is equally accepted)
- Import signature from photo or image file
- Photo-based signature capture
- Custom ink brushes, opacity, or pressure settings
- Change stroke thickness after a signature is saved to the library
- Signature categories, folders, or cloud sync
- Custom page number font picker
- Drag-and-drop import (import is via file picker button only)

---

*End of product behaviour specification.*
