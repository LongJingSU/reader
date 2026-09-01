# Book Format Routing

Choose the rendering model that preserves the useful reading experience of the supplied source.

## Scans and page photos

For user-supplied scans or photographs of a copy they own:

1. preserve the originals unchanged;
2. deskew, rotate, crop, and order pages when needed;
3. OCR in the requested language and retain page boundaries for traceability;
4. verify a sample from the beginning, middle, and end before building the reader;
5. use reflowable text when OCR quality is reliable, otherwise retain page images with a searchable OCR layer.

Do not use this route to capture an entire gated web reader or defeat access controls.

## EPUB or accessible HTML

Use a reflowable reader. Follow the EPUB container and OPF spine order, preserve semantic block structure, localize images, sanitize active content, and store one chapter record per spine document. EPUB is the preferred input for the current workbench.

## TXT or Markdown

Use a reflowable reader. Detect encoding, preserve paragraphs and intentional separators, and infer chapters conservatively from explicit headings. Do not invent chapter titles when the source has none.

## DOCX

Use the documents skill to extract headings, paragraphs, lists, tables, images, captions, footnotes, and order. Convert to sanitized semantic HTML, not screenshots of pages, unless layout fidelity is the user's primary requirement.

## PDF

Use the PDF skill to determine whether the file has a usable text layer and whether it is fixed-layout or scanned.

- For ordinary text PDFs, prefer a reflowable semantic reader when extraction preserves reading order.
- For fixed-layout, illustrated, or scanned books, preserve page appearance with local PDF rendering and attach annotations to page coordinates. Do not claim reflow fidelity when OCR or reading order is uncertain.
- Keep the original PDF untouched and make OCR/search text a derived artifact with its confidence limitations recorded.

## Multiple volumes or mixed files

Do not silently merge editions. Confirm which files belong to the same book, preserve their order, and give each volume a stable identity and storage namespace.
