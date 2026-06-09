# Lightroom Classic — Metadata, XMP, Keywords & Map

Library module unless noted. Mac shortcuts. **[inferred]** = standard but not pulled verbatim from a fetched Adobe page this session.

## Metadata panel
Right panel group. Top pop-up selects a view preset: Default, EXIF, EXIF and IPTC, IPTC, IPTC Extension, Location, Minimal, Quick Describe, Large Caption, All Plug-in Metadata **[inferred — standard set]**. A **Customize** button (newer versions) chooses which fields show. Capture time is kept to **millisecond** precision.

### Edit Capture Time (Metadata > Edit Capture Time…)
Three modes:
1. **Adjust to a specified date and time** — type into **Corrected Time** (absolute new time).
2. **Shift by set number of hours (time zone adjust)** — pop-up offset, forward/back (relative).
3. **Change to file's creation date** — sets EXIF capture time to the filesystem creation date.
Multi-select in **Grid**: active photo gets the change, others shift by the **same amount**. In Loupe/Compare/Survey filmstrip selection: only the **active** photo changes. Revert: **Metadata > Revert Capture Time To Original**.

### Save / Read metadata
- **Save Metadata to File** (`Cmd+S`, Metadata menu) = **catalog → file/XMP**. Writes keywords, IPTC, ratings/labels, develop settings out so Bridge/ACR can see them.
- **Read Metadata from File** = **file/XMP → catalog** (**overwrites** catalog values for those photos).
- **Conflict badge:** if metadata changed externally, the thumbnail shows a **"Metadata Was Changed Externally"** icon (and "Error Saving Metadata" if a save failed). Click the icon → choose **Import Settings from Disk** (file wins) or **Overwrite Settings** (catalog wins). *Read Metadata from File* = same as Import Settings from Disk.

## XMP — where it's stored
- **Proprietary raw** (CR2, NEF, ARW…): LR writes a **sidecar `.xmp`** next to the raw (same base name); the raw is never modified.
- **DNG / JPEG / TIFF / PSD / PNG**: XMP is written **into the file** (embedded), no sidecar.
- The **catalog is authoritative**; XMP is the interchange copy external apps read.
- **Catalog Settings > Metadata > "Automatically write changes into XMP"**: ON = LR continuously writes XMP (~every 10s for the active image) — files stay in sync, more disk I/O. OFF (default) = edits live only in the catalog until you manually `Cmd+S`.

## Keywords
- **Keywording panel** = apply keywords to selected photos (Keyword Tags box, Keyword Suggestions, Keyword Set of 9). **Keyword List panel** = the whole catalog keyword list; each has a target box (checkmark applies/removes on the selected photo) and a usage count.
- Add: type (comma-separated), click a suggestion/set, click a target box, or drag photos↔keyword.

### Hierarchical keywords
- Keywords can **contain** nested keywords. When **typing** a hierarchy, LR accepts separators **`|`, `<`, or `>`** (e.g. `animal | dog`, `animal > dog`, `dog < animal`).
- Create a child in Keyword List: right-click parent > **Create Keyword Tag inside "[parent]"…** **[inferred wording]**. To auto-nest new keywords under a parent: right-click > **Put New Keywords Inside this Keyword** (a dot marks it).
- **Keyword Tag Options** (double-click a keyword): **Synonyms**, **Include on Export**, **Export Containing Keywords**, **Export Synonyms**.

### ⭐ How hierarchy is stored in XMP — `lr:hierarchicalSubject`
- Written to XMP property **`lr:hierarchicalSubject`** (namespace `lr` = `http://ns.adobe.com/lightroom/1.0/`), an unordered bag of Text, one entry per checked keyword.
- **Separator is the pipe `|`** (NOT `>`). Each entry runs top-of-hierarchy → keyword, e.g. **`Family|Doug&Maggie|Trips`**. The `<`/`>`/`|` choice is only for *typed input*; serialized XMP always uses `|`. **This confirms the project's CLAUDE.md convention is correct.** (Flat keywords also go to `dc:subject` / IPTC Keywords.)
- Verified across Adobe Community, ExifTool, Lightroom Queen, Exiv2 `lr` schema.

### Import/Export keyword lists
- **Metadata > Export Keywords…** — plain-text, hierarchy as **tab indentation** (children indented under parents). A `.csv` variant exports keyword options (synonyms/flags).
- **Metadata > Import Keywords…** — imports tab-indented text (UTF-8, tab-delimited if special chars). Rebuilds hierarchy from indentation. Example:
```
Family
	Curran
	Doug&Maggie
		Trips
		Anniversary
```

## Map module (geotagging) — must be online (Google map)
- **Place photos:** drag from Filmstrip onto the map, or right-click a location > add selected; photos with GPS appear as pins automatically.
- **GPS fields** in the Metadata panel (Location / EXIF and IPTC presets): paste `lat,long`; Altitude, Direction, and IPTC Sublocation/City/State/Country/ISO are editable.
- **Reverse geocoding / Address Lookup** (Catalog Settings > Metadata): **Enable reverse geocoding of GPS coordinates** sends coords to Google to fill City/State/Country (suggestions show **gray italic** until accepted; privacy switch — off = nothing sent). **Export reverse geocoding suggestions whenever address fields are empty** includes them on export. Strip on export via Export dialog > **Remove Location Info**.
- **Tracklog:** **Map > Tracklog > Load Tracklog…** (GPX only) → matches photos by capture time → **Auto-Tag [N] Selected Photos** interpolates GPS onto matching photos; **Set Time Zone Offset…** aligns camera clock vs GPS/UTC. **[submenu items partly inferred]** (This mirrors the project's GPS-fill approach: interpolate iPhone GPS onto Canon 7D frames by matching time.)

## Sources
helpx.adobe.com/lightroom-classic: metadata-basics-actions, advanced-metadata-actions, create-xmp-acr-files, keywords, maps-module, create-catalogs; exiv2.org/tags-xmp-lr; Adobe Community lr:hierarchicalSubject thread.
