import { useParams } from "@tanstack/react-router";
import { Share2, Trash2 } from "lucide-react";
import { useState } from "react";
import { LoadError, Loading } from "@/components/PageState";
import { Reader } from "@/components/Reader";
import { RemoveDialog } from "@/components/RemoveDialog";
import { ShareDialog } from "@/components/ShareDialog";
import { SignIn } from "@/components/SignIn";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { useT } from "@/lib/i18n";

/** One of my books, at a part: the reader, with ways to share it or remove it from the site. */
export function Chapter() {
  const t = useT();
  const { id, part } = useParams({ from: "/book/$id/$part" });
  const [sharing, setSharing] = useState(false);
  const [removing, setRemoving] = useState(false);
  const { data, error, refetch } = useCharacterBook(Number(id));
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  return (
    <>
      <Reader
        character={data.character}
        book={data.book}
        part={part}
        hrefFor={(p) => `/book/${id}/${p}`}
        actions={
          <>
            <button onClick={() => setSharing(true)} aria-label={t.share.title} title={t.share.title} aria-haspopup="dialog" className="rounded p-1.5 text-gold-bright hover:bg-gold/10">
              <Share2 className="size-5" />
            </button>
            <button
              onClick={() => setRemoving(true)}
              aria-label={t.remove.title}
              title={t.remove.title}
              aria-haspopup="dialog"
              className="rounded p-1.5 text-parchment/60 hover:bg-[#e0705f]/10 hover:text-[#e0705f]"
            >
              <Trash2 className="size-5" />
            </button>
          </>
        }
      />
      <ShareDialog open={sharing} onClose={() => setSharing(false)} character={data.character} book={data.book} part={part} />
      <RemoveDialog open={removing} onClose={() => setRemoving(false)} character={data.character} />
    </>
  );
}
