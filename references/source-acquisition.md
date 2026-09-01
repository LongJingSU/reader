# Outcome-Oriented Source Acquisition

Use this reference only when the user names a book but does not provide a usable local file.

## Search order

Determine the target language before searching. Use the language of the user's conversation unless they explicitly request another edition. For Chinese requests:

1. search the exact Chinese title and author, preferring a complete Simplified Chinese edition;
2. search known alternate Chinese titles, translator names, publisher pages, and ISBNs;
3. check a complete Traditional Chinese edition when Simplified Chinese is unavailable;
4. propose the original-language or another-language edition only after clearly reporting the Chinese-edition result.

Do not silently substitute an English original for a requested Chinese translation. Machine translation of an entire copyrighted book is not a substitute for acquiring an authorized Chinese edition.

## Success contract

Classify the result as one of these states:

- `LOCAL_FILE_READY`: a complete local file exists, opens successfully, matches the requested language and edition, and is ready for extraction or OCR;
- `ONE_USER_ACTION_REQUIRED`: an exact authorized copy has been verified, but the user must perform one bounded action such as purchasing, borrowing, signing in, exporting, uploading their owned file, or supplying scans;
- `NO_AUTHORIZED_COPY_FOUND`: all applicable source classes below were checked and none produced a usable local copy.

Only `LOCAL_FILE_READY` counts as “found and downloaded.” Do not present a retailer listing, catalog record, preview, or app-only reading page as successful delivery. Keep provenance and failed-search detail in the work record; lead the user-facing response with whether the book can be opened locally.

## Exhaustive discovery

1. Search the author and publisher sites for an official download, companion edition, translation, or temporary free promotion.
2. Check authorized ebook retailers and reading services for downloadable, printable, or supported user-exportable editions; keep searching when a service is in-app-only.
3. Check national, provincial, municipal, university, and institutional library catalogs for digital loans or downloadable collections available to the user.
4. Check public-domain and open-license sources appropriate to the language, such as Project Gutenberg, Standard Ebooks, Wikisource, Internet Archive collections with clear access rights, and official institutional repositories.
5. Check alternate editions: original and translated titles, older editions, revised editions, translator names, publishers, and each known ISBN.
6. If the user already owns or can access the book, use the provider's normal download/export controls or ask for the smallest user action needed to supply that file.
7. If the user owns a paper copy, accept their scans or page photos and use OCR. Do not ask the user to capture a gated online book page by page.
8. If the work is public domain or openly licensed for derivatives and no requested-language edition exists, acquire the authorized original and produce a clearly labeled machine-assisted translation for the private reader.

For each route, try the title, original title, author, translator, publisher, ISBN, and common format terms (`EPUB`, `PDF`, `HTML`, `TXT`) as appropriate. Compare multiple candidate pages, verify that a real download or entitled export exists, and prefer EPUB/HTML over fixed-layout PDF for the workbench. A lawful result may be free, borrowed, purchased, or supplied by the user; it does not have to be zero-cost.

Search for an obtainable file, not merely evidence that the book exists. Continue after finding a platform-only edition when other source classes remain unchecked. Prefer primary provider pages for acquisition and use metadata/catalog pages only to discover alternate titles, ISBNs, editions, and holdings.

When a candidate file is available:

1. save it to a bounded local destination;
2. check its extension, MIME/signature, byte size, and archive/PDF integrity;
3. open or extract enough content to verify title, author, language, completeness, and absence of an unrelated or sample-only work;
4. hash it and record provenance;
5. move immediately into reader construction when checks pass.

If no immediately downloadable copy exists but an exact authorized route is verified, ask for only the action that unlocks progress—for example, “请购买并点击平台的 EPUB 导出，然后把文件发给我” or “请上传你这本纸书的扫描件.” Do not end with a long generic list of bookstores. Resume the build as soon as the file is available.

Verify the exact title, author, edition, language, publisher, file type, and whether the source actually grants download or offline use. Save the canonical page URL and the acquisition date.

## Stop conditions

Do not:

- use piracy indexes, shadow libraries, unauthorized mirrors, torrents, leaked cloud-drive links, or search snippets that merely claim a free copy exists;
- bypass login, payment, geographic controls, rate limits, robots controls, or expiring access restrictions;
- strip or defeat DRM, decrypt protected files, capture an entire gated book page by page, or reuse another person's account/session;
- treat “personal use” as proof that copying is authorized.

If only preview chapters are lawfully accessible, do not represent them as the complete book. Tell the user what is available and offer the shortest legitimate path to a full local file.

Do not guarantee success when the rights holder offers no local-file edition and the user has not supplied an owned copy. Persistence means exhausting credible authorized routes and minimizing the remaining user action, not fabricating availability or using an unauthorized source.

## Provenance record

Record:

- canonical source URL and provider;
- visible price/free/lending status at acquisition time;
- title, author, edition/translation, publisher, ISBN when available;
- local source path, byte size, format, and SHA-256;
- access or evidence limitations.
