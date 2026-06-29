# PDF Pages — Product Behaviour Specification

This document describes **exactly how the app behaves today** from the user's perspective. It is intended for designers, product managers, QA engineers, and other agents who need to understand the product without reading source code.

**Last verified against:** the codebase as of the current release (includes Document Mode, Page Mode, overlays, signatures with Quick Signature and default/favorite, signature stroke thickness, page numbers, compression, export, appearance settings, and horizontal Page Mode navigation).

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [App launch and global behaviour](#2-app-launch-and-global-behaviour)
3. [Home / empty state (no document open)](#3-home--empty-state-no-document-open)
4. [Import](#4-import)
5. [Settings](#5-settings)
6. [Document Mode](#6-document-mode)
7. [Page thumbnails (Document Mode)](#7-page-thumbnails-document-mode)
8. [Page reordering](#8-page-reordering)
9. [Page rotate, duplicate, delete](#9-page-rotate-duplicate-delete)
10. [Document Actions menu](#10-document-actions-menu)
11. [Export](#11-export)
12. [Paywall (export limit)](#12-paywall-export-limit)
13. [Compression](#13-compression)
14. [Page Numbers](#14-page-numbers)
15. [Page Mode](#15-page-mode)
16. [Page Mode navigation (swipe between pages)](#16-page-mode-navigation-swipe-between-pages)
17. [Page Mode zoom and pan](#17-page-mode-zoom-and-pan)
18. [Adding content in Page Mode](#18-adding-content-in-page-mode)
19. [Image overlays](#19-image-overlays)
20. [Signatures — library, drawing, placement](#20-signatures--library-drawing-placement)
21. [Overlay selection and manipulation](#21-overlay-selection-and-manipulation)
22. [Gesture reference (complete)](#22-gesture-reference-complete)
23. [Gesture priorities and conflicts](#23-gesture-priorities-and-conflicts)
24. [Undo](#24-undo)
25. [Empty, loading, and error states](#25-empty-loading-and-error-states)
26. [Accessibility](#26-accessibility)
27. [Persistence and app restart](#27-persistence-and-app-restart)
28. [Limits and defaults](#28-limits-and-defaults)
29. [Known limitations](#29-known-limitations)
30. [Features not implemented](#30-features-not-implemented)

---

## 1. Product overview

**PDF Pages** is an iOS app for working with PDF documents. The user can:

- Import a PDF
- View all pages in a scrollable grid (**Document Mode**)
- Reorder, rotate, duplicate, and delete pages
- Open a single page for detailed editing (**Page Mode**)
- Add image overlays and signatures on individual pages (including one-tap **Quick Signature** when a default is set)
- Apply document-wide page numbers
- Compress the document
- Export a new PDF reflecting all changes
- Change app appearance (light / dark / device)
- Undo many editing operations

The app does **not** modify the user's original imported file. All edits are held in memory (and temporary app storage for the working copy) until export.

There is **no** recent-documents list, **no** project saving, **no** multi-document library, and **no** account system.

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
├── Home (empty) OR Document Mode
│   ├── Settings (sheet)
│   └── Page Mode (pushed navigation)
│       ├── Add options (sheet: Image, Quick Signature, Signature Library)
│       ├── Photos picker (system)
│       ├── Signature Library (sheet)
│       └── Signature Capture (sheet, from library)
├── Compression (sheet, from Document Actions)
├── Page Numbers (sheet, from Document Actions)
├── Paywall (sheet, from Export when over free limit)
└── Export share sheet (system share)
```

---

## 3. Home / empty state (no document open)

### What the user sees

- Large document icon (`doc.on.doc`)
- Title: **"PDF Pages"**
- Subtitle: **"Rearrange, delete, rotate, and export PDF pages."**
- Prominent button: **"Import PDF"**
- Background: grouped system background (light grey in light mode)
- Settings gear in top-right

### What the user can do

| Action | Result |
|--------|--------|
| Tap **Import PDF** | Opens the system file picker limited to **PDF files**, **single selection only** |
| Tap **Settings** | Opens Settings sheet |

### If the user cancels import

- File picker closes
- User remains on home screen
- No error shown

---

## 4. Import

### Entry point

- **Import PDF** button on home screen

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
- Undo history is **cleared**
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

- Import state is **not** restored. User sees home screen and must import again.

---

## 5. Settings

### Entry point

- **Gear icon** (top-right), available on home and Document Mode
- Accessibility label: **"Settings"**

### What the user sees

- Sheet titled **"Settings"**
- One section: **"Appearance"**
- Segmented control with three options: **Device**, **Light**, **Dark**
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

## 6. Document Mode

### When shown

- After successful PDF import
- After tapping **Done** from Page Mode (back navigation)
- After **Continue Editing** from compression (re-imports compressed file)

### What the user sees

- Navigation title: **document file name** (without `.pdf`)
- **Toolbar (leading):**
  - **New PDF** — starts a new session
  - **Undo** — undoes last action (disabled when nothing to undo)
- **Toolbar (trailing):**
  - **⋯ (ellipsis.circle)** — Document Actions menu (disabled if all pages deleted)
- **Main content:** scrollable grid of page thumbnails (see [Page thumbnails](#7-page-thumbnails-document-mode))

### Empty document state (all pages deleted)

If the user deletes every page:

- **ContentUnavailableView** appears:
  - Title: **"No Pages"**
  - Icon: document
  - Message: **"All pages were removed. Tap New PDF to import another document."**
- Grid is hidden
- Document Actions menu is **disabled**

### New PDF

Tapping **New PDF**:

1. Any temporary export file from a previous share is deleted
2. Paywall and share sheets are dismissed if open
3. The working PDF copy in temp storage is deleted
4. All session state is cleared (pages, overlays, undo, page numbers)
5. Thumbnail cache is cleared
6. User returns to **home / empty state**

**No confirmation dialog** is shown.

### Scrolling

- The page grid is in a vertical **ScrollView**
- Grid uses adaptive columns (minimum ~140 pt, maximum ~180 pt per column)
- Spacing between cards: 16 pt

---

## 7. Page thumbnails (Document Mode)

### What each thumbnail card shows

1. **Page preview image** — rendered PDF page, including:
   - Current rotation
   - Image/signature overlays composited on top
   - Applied page numbers (if page numbers are enabled and apply to this page)
2. **Position badge** (top-left of thumbnail): shows **"1"**, **"2"**, etc. — the page's **current position** in the document list (not the same as applied page-number text unless coincidentally matching)
3. **Three action buttons** below the thumbnail:
   - **Rotate** (rotate.right icon)
   - **Duplicate** (plus.square.on.square icon)
   - **Delete** (trash icon, destructive styling)

### Thumbnail loading

- While loading: **spinning ProgressView** inside the thumbnail frame
- Thumbnail reloads when: rotation changes, overlays change, page numbers change, or page order changes
- Cached for performance; cache cleared on undo and some global changes

### Thumbnail sizing

- **Portrait-style pages** (0° or 180° rotation): fixed height **200 pt**, width from aspect ratio
- **Landscape-style pages** (90° or 270° rotation): fixed width **200 pt**, height from aspect ratio
- Thumbnail is scaled to fit within the card

### Tap thumbnail

- Opens **Page Mode** for that page (navigation push)
- Navigation title in Page Mode: **"Page N"** where N is current list position

### Visual feedback during page drag-reorder

- While dragging a page in the grid, that thumbnail's opacity becomes **50%**

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
| **Export** | square.and.arrow.up | Export flow (may show paywall) |

---

## 11. Export

### Entry point

- **Export** in Document Actions menu

### What gets exported

A **new PDF file** built from:

- Current page list and order
- Per-page rotation
- Image and signature overlays
- Applied page numbers (if enabled)
- Original PDF page content preserved as vector where possible (searchable text on supported paths)

The exported file name: **`{documentName}-arranged.pdf`** (slashes and colons in the name replaced with hyphens).

### Flow (within free limit)

1. User taps Export
2. App generates PDF to a **temporary file**
3. **iOS share sheet** appears with the PDF
4. User can AirDrop, Save to Files, Mail, etc.
5. When share sheet is dismissed, the temporary export file is **deleted**

### Export failure

- Alert: **"Export Failed"** with message **"Could not export the PDF."** (or other error text)
- **OK** dismisses alert
- User remains in Document Mode; no file is shared

### Export with paywall

See [Paywall](#12-paywall-export-limit).

### Cancel

- Dismissing the share sheet without sharing: no error; temp file cleaned up
- No changes to the editing session

### Repeat export

- Each export generates a **fresh** temporary file
- Reflects **current** document state at time of export

### After app restart

- No export occurs automatically; user must export again

---

## 12. Paywall (export limit)

### When shown

- When exporting a document with **more than 20 pages** and Pro is not unlocked for the session

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

1. Automatically prepares input by **exporting the current document** (same as export pipeline)
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
- **Save / Share** — opens share sheet with compressed PDF
- **Continue Editing** — **replaces the entire session** by importing the compressed PDF (same as new import of that file); dismisses compression sheet

### Close without continuing

- **Close** on configuration or result (when not compressing): dismisses sheet
- Temporary prepared export file is cleaned up
- **Session unchanged** unless user tapped **Continue Editing**

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

## 15. Page Mode

### Entry point

- Tap any page thumbnail in Document Mode

### What the user sees

- Navigation title: **"Page N"** (N = position in current list, 1-based)
- **Back** chevron (system) — returns to Document Mode
- **Done** button (top-right) — same as back; returns to Document Mode
- **Main area:** page preview scaled to **fill the maximum horizontal width** (16 pt margin from each safe-area edge); aspect ratio preserved; document centered horizontally; any extra vertical space remains below the page
- **Bottom bar:** prominent **Add** button (plus.circle.fill)

### Loading state

- While page image loads: centred **"Loading page…"** with progress spinner
- Only the **current page** is loaded (not the whole document)

### Toolbar when overlay selected

- **Delete** button (destructive, top-right) appears in addition to **Done**
- Deletes the **selected** overlay

### Leaving Page Mode

| Action | Result |
|--------|--------|
| **Done** | Pop to Document Mode |
| **Back swipe / back button** | Pop to Document Mode |
| Session state (overlays, order, etc.) | **Preserved** |

### Page-specific vs document state

- Overlays belong to **specific pages** (by internal page ID)
- Navigating between pages in Page Mode does **not** move overlays between pages
- Changing pages **clears overlay selection**
- Page zoom/pan resets when changing pages (fresh canvas per page)

---

## 16. Page Mode navigation (swipe between pages)

### Gestures

| Gesture | Result |
|---------|--------|
| **Swipe left** (horizontal, on page canvas) | **Next page** (if not on last page) |
| **Swipe right** (horizontal, on page canvas) | **Previous page** (if not on first page) |

### Animation

- Page content transitions with **0.25 s ease-in-out** slide animation
- Next page: slides in from trailing edge
- Previous page: slides in from leading edge
- Navigation title updates to new **"Page N"**

### Boundaries

| Situation | Behaviour |
|-----------|-----------|
| First page, swipe right | **Nothing** — no bounce, no wrap |
| Last page, swipe left | **Nothing** — no bounce, no wrap |

### Swipe recognition rules

- Minimum horizontal distance: **~60 pt**
- Horizontal movement must be **~1.35× greater than vertical** (diagonal/vertical swipes ignored)
- Minimum drag distance before gesture activates: **20 pt**

### Blocked when

- Page is **zoomed** (scale > 1 or panned off centre)
- User is **actively manipulating an overlay** (dragging, resizing, or pinch-resizing)

### Allowed when

- Page at default zoom
- Overlay **selected but idle** (swipe on empty canvas area still works)
- Overlay not selected

### Undo

- Page navigation does **not** create undo entries

---

## 17. Page Mode zoom and pan

### When available

- Only when **no overlay is selected**

### Pinch zoom

- **Pinch out:** zoom in up to **4×**
- **Pinch in:** zoom out down to **1×**
- If user ends pinch at ≤1×: zoom **animates back** to 1× (0.2 s ease-in-out)

### Pan (drag)

- Only when zoomed **above 1×**
- Drag to move the zoomed page around the viewport

### Double tap

- When no overlay selected: **resets zoom and pan** to default (animated 0.2 s)

### Single tap on canvas (empty area)

- **Deselects** any selected overlay

### When overlay is selected

- Page pinch/pan/double-tap zoom are **disabled**
- User can still pinch the **selected overlay** to resize it (see [Overlays](#21-overlay-selection-and-manipulation))

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
| **Text** | Coming soon | **No** | — |
| **Image** | Import from Photos or Files | **Yes** | Dismisses sheet → opens **Photos picker** |
| **Quick Signature** | Place your default signature | **Yes** | Dismisses sheet → places default signature immediately (see below), or opens **Signature Library** if none is available |
| **Signature Library** | Choose, create, or manage signatures | **Yes** | Dismisses sheet → opens **Signature Library** |

### Quick Signature

**Entry:** Add → **Quick Signature**

| Situation | Result |
|-----------|--------|
| **Case A** — User has an explicit **Default Signature** set | Signature is placed on the current page **immediately** (Add sheet dismisses; library does **not** open). Placed overlay is **auto-selected**. |
| **Case B** — User has **exactly one** saved signature and **no** explicit Default Signature | That signature is placed **immediately** with the same auto-select behaviour. User is **not** required to mark it as default. |
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
- Tap a signature tile (thumbnail area) → places on current page, **dismisses library**; placed overlay is **auto-selected**

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
- If there is **exactly one** saved signature and **no** explicit Default Signature, Quick Signature still places it immediately (Case B; star/badge remain unset until the user taps the star)

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
3. Places signature on current PDF page
4. Dismisses capture and library sheets; placed overlay is **auto-selected**

### Signature on page

- Treated as an overlay of type **signature**
- Initial width: **30%** of page width (slightly smaller than images)
- Initial height: derived from the saved PNG aspect ratio so the overlay frame matches the signature image (`height = width × imageHeight / imageWidth` on the page); no vertical letterboxing inside the frame
- Same move/resize/delete behaviour as image overlays
- When placed from Quick Signature, Signature Library, or Save & Use, the new overlay is **selected automatically**

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

Applies to **image overlays** and **signature overlays** (same UI).

### Selection

| Action | Result |
|--------|--------|
| **Tap overlay** (not selected) | Selects overlay; shows blue border, delete (×) top-right, resize handle bottom-right; brings overlay to **front** if it was behind another |
| **Tap empty canvas** | Deselects |
| **Select another overlay** | Switches selection |
| **Place overlay** (image import, Quick Signature, Signature Library, or Save & Use) | New overlay is **auto-selected** with placement haptic + animation |

**Only one overlay selected at a time.** No multi-select.

### Overlay placement feedback

When the user **newly places** an image or signature overlay in Page Mode (image import, Quick Signature, Signature Library, or Save & Use):

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
- **Drag handle** to resize uniformly (aspect ratio preserved)
- Size clamped between **8%** and **95%** of page dimension
- **Undo:** one entry per completed resize
- Uses **high-priority gesture** so page navigation does not interfere
- **Blocks page swipe** while resizing

### Resize — pinch

- **Pinch** on selected overlay to scale
- Same size limits as handle resize
- **Undo:** one entry per completed pinch
- **Blocks page swipe** while pinching

### Delete

Three ways:

1. Red **×** button on overlay (top-right when selected)
2. **Delete** in Page Mode toolbar (when overlay selected)
3. All create **undo** entries

### Z-order

- Tapping an overlay brings it to front (updates z-index)
- If already frontmost: **no undo entry**

### Overlay rotation (object rotation)

- Data model supports overlay rotation; **no user gesture** to rotate overlays in the current UI

### Opacity

- Fixed at 100% in current UI (not user-adjustable)

---

## 22. Gesture reference (complete)

### Home / empty state

| Gesture | Target | Effect |
|---------|--------|--------|
| Tap | Import PDF | Open file picker |
| Tap | Settings | Open settings |

### Document Mode

| Gesture | Target | Effect |
|---------|--------|--------|
| Tap | Thumbnail | Open Page Mode |
| Tap | Rotate / Duplicate / Delete | Page action |
| Tap | New PDF / Undo / ⋯ menu | Toolbar actions |
| **Drag** | Thumbnail | Reorder pages |
| **Scroll** | Grid | Scroll document |

### Page Mode — canvas

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Empty canvas | Deselect overlay |
| **Double tap** | Canvas (no overlay selected) | Reset zoom |
| **Pinch** | Canvas (no overlay selected) | Zoom page 1×–4× |
| **Drag** | Canvas (zoomed, no overlay selected) | Pan zoomed page |
| **Swipe left/right** | Canvas (conditions met) | Next/previous page |
| **Scroll** | — | No scroll in page view (fixed layout) |

### Page Mode — overlay (selected)

| Gesture | Target | Effect |
|---------|--------|--------|
| **Tap** | Overlay (unselected) | Select |
| **Drag** | Overlay | Move |
| **Drag** | Resize handle | Resize |
| **Pinch** | Overlay | Resize |
| **Tap** | × button | Delete overlay |

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

1. **Overlay resize handle drag** (`highPriorityGesture`) — always wins on handle
2. **Overlay drag / pinch** (when selected) — blocks page navigation while active
3. **Overlay tap** — select
4. **Page pinch/pan** (when no overlay selected)
5. **Page swipe navigation** (when not zoomed, not manipulating overlay)
6. **Canvas tap** — deselect

**Specific rules:**

| Situation | Page swipe | Page zoom | Overlay edit |
|-----------|------------|-----------|--------------|
| Overlay being dragged | ❌ Blocked | N/A | ✅ Active |
| Overlay being resized (handle or pinch) | ❌ Blocked | N/A | ✅ Active |
| Overlay selected, idle | ✅ On empty canvas | ❌ Disabled | ✅ Tap to edit |
| Page zoomed | ❌ Blocked | ✅ Pan/pinch | ❌ Select only |
| Nothing selected, default zoom | ✅ | ✅ | — |

**Intentional design:** Overlay editing always takes precedence over page navigation during active manipulation. Page navigation and page zoom are mutually exclusive (zoom blocks swipe).

---

## 24. Undo

### Entry point

- **Undo** button in Document Mode toolbar (leading)
- **Disabled** when undo stack is empty (greyed out)
- **Not available** in Page Mode toolbar (user must return to Document Mode)

### Animation

- Undo runs with SwiftUI **animation**

### What undo restores

Single snapshot of:

- Page list (order, rotations, which pages exist)
- All overlays on all pages
- Overlay image assets in memory
- Page number settings

### Actions that push undo (one entry each)

- Page delete
- Page rotate
- Page duplicate
- Page reorder (entire drag operation)
- Add overlay (image or signature)
- Move overlay (on release)
- Resize overlay (handle or pinch, on release)
- Delete overlay
- Bring overlay to front (only if z-order actually changes)
- Apply page numbers
- Remove page numbers

### Actions that do NOT push undo

- Navigating in Page Mode (swipe between pages)
- Opening/closing sheets
- Importing / New PDF (clears undo stack)
- Export / share
- Compression (unless **Continue Editing** replaces document — that is a new import with cleared undo)
- Changing appearance settings
- Selecting/deselecting overlay without moving it
- Zooming/panning page in Page Mode

### Undo limit

- Maximum **50** undo steps; oldest entries dropped

### Repeat undo

- Each tap undoes **one** more step

### After app restart

- Undo history is **empty**

---

## 25. Empty, loading, and error states

| Context | State | What user sees |
|---------|-------|----------------|
| No document | Empty home | PDF Pages title, Import button |
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

- Many controls have `accessibilityIdentifier`s for UI testing (import button, settings, thumbnails, page mode, overlays, compression, export, etc.)
- Page Mode view exposes `accessibilityValue`: **"page N of M"**
- Settings gear: accessibility label **"Settings"**
- Document Actions: accessibility label **"More"**
- Thumbnail action buttons: accessibility labels **"Rotate"**, **"Duplicate"**, **"Delete"**
- Overlay delete button: **"Delete image"**
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
| Signature library (saved signatures) | **Yes** |
| Default / favorite signature | **Yes** |
| Last signature ink thickness (capture UI) | **Yes** |
| Open document / pages / overlays | **No** |
| Undo history | **No** |
| Page number settings | **No** |
| Pro unlock | **No** |
| Import temp files | **No** (cleaned on New PDF / close) |

After restart: user sees **home screen** and must **Import PDF** again. Saved signatures, default signature, and last ink thickness remain available next time they add or draw a signature.

---

## 28. Limits and defaults

| Item | Value |
|------|-------|
| Free export page limit | **20 pages** |
| Undo stack depth | **50** |
| Page zoom max | **4×** |
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
| Multi-page selection | **Not supported** |
| Text overlays | **Not implemented** (shown as "Coming soon") |

---

## 29. Known limitations

1. **No session persistence** — closing the app loses all document edits unless exported.
2. **No recent documents** — user must re-import every session.
3. **Paywall is a placeholder** — "Continue for now" unlocks Pro for the session only; no real purchase.
4. **Paywall lists "coming soon" features** (merge & split, batch tools) that are not in the app.
5. **Text overlays** — shown in Add menu but disabled ("Coming soon").
6. **No watermark, OCR, split, merge, password protect** in Document Actions (commented as future only).
7. **Page number font size and opacity** — not user-configurable in UI.
8. **Overlay opacity and rotation** — not user-configurable in UI.
9. **No multi-select** for pages or overlays.
10. **No redo** — only undo.
11. **Deleting a page** — no confirmation dialog.
12. **New PDF** — no confirmation; immediate session loss.
13. **Image import failure** — silent (no error if photo data invalid).
14. **Signature rename failure** — silent (no error alert).
15. **Compression "Continue Editing"** replaces the entire session and clears undo (by design of re-import).
16. **Document name** in title comes from imported file name; user cannot rename in app.
17. **Thumbnail position badge** (1, 2, 3…) is always list position; it is independent of page-number feature formatting unless values coincide.
18. **Page Numbers preview** in setup sheet always reflects the **last page** in the document, not the page currently being edited in Page Mode.

---

## 30. Features not implemented

The following are **not** available in the current product (do not test for them):

- Recent documents list
- Save project / reopen project
- Multiple open documents
- Text overlay editing
- Watermark
- OCR
- Split / merge PDFs
- Password protect PDF
- Document rename
- Document information panel
- Batch tools
- Real in-app purchase / subscription
- Redo
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
