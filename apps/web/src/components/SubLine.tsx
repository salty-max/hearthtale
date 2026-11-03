import { Fragment } from "react";

/** The line under an entry's title, its pieces joined by " · ": the place in the book's language, the rest the page's. */
export function SubLine({ pieces, bookLang }: { pieces: { text: string; book?: true }[]; bookLang: string }) {
  return (
    <>
      {pieces.map((x, i) => (
        <Fragment key={i}>
          {i > 0 && " · "}
          {x.book ? <span lang={bookLang}>{x.text}</span> : x.text}
        </Fragment>
      ))}
    </>
  );
}
