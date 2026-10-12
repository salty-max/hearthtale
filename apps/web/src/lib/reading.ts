/** A page that is a book being read: it fills the frame, and on phones the tab bar steps aside for it. */
export function isReading(path: string): boolean {
  return /^\/book\/\d+\/(?!road$)[^/]+$/.test(path) || /^\/s\/[^/]+$/.test(path) || /^\/hall\/\d+$/.test(path);
}

/**
 * What a page is, for its fade on arriving: its address, but one book for all
 * its parts (/book/3/2 and /book/3/3 are both /book/3), so turning a page
 * keeps the reader in place and only its text changes.
 */
export function pageOf(path: string): string {
  const book = /^(\/book\/\d+)(\/(?!road$)[^/]+)?$/.exec(path);
  return book ? book[1] : path;
}
