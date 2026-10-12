/** A page that is a book being read: it fills the frame, and on phones the tab bar steps aside for it. */
export function isReading(path: string): boolean {
  return /^\/book\/\d+\/(?!road$)[^/]+$/.test(path) || /^\/s\/[^/]+$/.test(path) || /^\/hall\/\d+$/.test(path);
}
