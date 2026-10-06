import { useRouter } from "@tanstack/react-router";
import type { AnchorHTMLAttributes } from "react";

/**
 * A link to a page of the app by its address (a book's part, wherever the book
 * is read from: your library, a share link, the Hall): navigates in the app,
 * and opens a new tab with a modifier like any link.
 */
export function PartLink({ href, onClick, ...rest }: AnchorHTMLAttributes<HTMLAnchorElement> & { href: string }) {
  const router = useRouter();
  return (
    <a
      href={href}
      onClick={(e) => {
        onClick?.(e);
        if (e.defaultPrevented || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
        e.preventDefault();
        void router.navigate({ href });
      }}
      {...rest}
    />
  );
}
