# Reader Workbench Contract

Use this reference when implementing or reviewing a reader.

## Product shape

The reader is a private working surface, not a marketing page or a generic notes dashboard.

- Header: book identity, overall progress, saved-state indicator, appearance control, backup/export.
- Left rail: cover and metadata, chapter count, directory, active chapter, full-text search.
- Book page: original reading hierarchy and images, generous paper surface, chapter-end navigation.
- Page margin: a subtle dashed divider, faint ruled-paper lines, and low-contrast “页边笔记” label. Margin cards sit here and connect to marked text.
- Do not add a permanent right-side notes panel or a sticky chapter toolbar above the page.

On narrow screens, prioritize readable text. The directory may become a drawer and margin cards may hide; never hide the underlying persistent highlight.

## Book data

Use a local `public/book/book-data.json` containing stable book metadata and ordered chapters. Each chapter needs at least:

```json
{
  "id": "stable-chapter-id",
  "order": 0,
  "section": "正文",
  "title": "章节标题",
  "source": "EPUB/original/path.xhtml",
  "html": "<p>sanitized local HTML</p>",
  "plainText": "用于搜索的纯文本"
}
```

Keep asset URLs local and root-relative under `/book/`. Preserve visible text exactly enough that stored character offsets remain stable across reloads.

## Reader state

Use a book-specific local key and versioned state:

```ts
type ReaderState = {
  version: 1;
  currentChapterId: string;
  highlights: Array<{
    id: string;
    chapterId: string;
    start: number;
    end: number;
    text: string;
    note: string;
    color: 'yellow' | 'rose' | 'sage';
    createdAt: string;
    updatedAt: string;
  }>;
  positions: Record<string, number>;
  settings: {
    fontSize: number;
    lineHeight: number;
    pageWidth: number;
    theme: 'paper' | 'sepia' | 'night';
  };
};
```

Autosave after a short debounce. JSON export must restore the full state. Markdown export should group quotes and annotations by chapter.

## Highlight rendering

Calculate selections against the visible text content of the sanitized chapter. Before render, split text nodes at stored boundaries and wrap active segments with semantic `mark.reader-highlight` elements carrying stable highlight IDs.

Do not use the CSS Custom Highlight API as the sole persistence layer. Do not inject marks into the mounted DOM and then render the original `dangerouslySetInnerHTML`, because React will erase them.

Clicking a saved mark opens a small anchored toolbar with “取消高亮”. When a new selection overlaps an old marker, replace the overlapping marker rather than stacking invisible duplicates.

## Margin annotations

A non-empty annotation adds:

- the selected color highlight;
- a wavy underline on the original text;
- a light connector from the last marked segment to a margin card;
- a margin card with the user's note, a short source-text cue, edit, and delete controls.

Lay cards out in source order and prevent vertical overlap. Keep connector and card geometry relative to the book page so scrolling does not detach them.

## Local launcher

Use a stable per-reader localhost port. The launcher should:

1. test whether the reader already responds;
2. start the existing package's development or production command in a hidden process when needed;
3. wait for a successful HTTP response with a bounded timeout;
4. open the stable URL;
5. show a useful local error message pointing to a log if startup fails.

Do not randomize the port after first delivery because browser storage is origin-scoped.
