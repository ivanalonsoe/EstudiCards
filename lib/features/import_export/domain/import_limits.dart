// Size limits for imported files. A file comes from outside the app, so it
// is checked before anything is decoded or written: a huge or malicious
// file is rejected with a clear message instead of freezing the app or
// filling its storage.

/// A JSON file (a backup with its images, or a shared project or deck). A
/// stored card image is a JPEG of at most 1600 px, usually 150–400 KB, and
/// base64 makes it a third bigger: 100 MB holds a few hundred images.
const int maxJsonFileBytes = 100 * 1024 * 1024;

/// A full backup (T5.10, decided with the owner): about 1,400 images. Before
/// "Exportar todo" writes one, its size is worked out; a bigger one could
/// not be restored, so the user is offered other ways.
const int maxBackupFileBytes = 500 * 1024 * 1024;

/// A CSV file. It has no images: 5 MB is tens of thousands of cards.
const int maxCsvFileBytes = 5 * 1024 * 1024;

/// Card rows in a CSV file, header not included. SPEC §9 plans for decks of
/// up to 5,000 cards; this leaves room for a project with several decks.
const maxCsvRows = 10000;

/// One card image inside a JSON file, once decoded from base64. The app
/// writes images of 1600 px at JPEG quality 80, well under 1 MB.
const int maxImageBytes = 5 * 1024 * 1024;
