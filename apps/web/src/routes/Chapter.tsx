import { Link, useParams } from "@tanstack/react-router";
import { ChevronLeft, Download, Map as MapIcon, MoreHorizontal, Share2, Trash2 } from "lucide-react";
import { useCallback, useState } from "react";
import { ExportDialog } from "@/components/ExportDialog";
import { Menu } from "@/components/Menu";
import { LoadError, Loading } from "@/components/PageState";
import { PrintBook } from "@/components/PrintBook";
import { Reader } from "@/components/Reader";
import { RemoveDialog } from "@/components/RemoveDialog";
import { ShareDialog } from "@/components/ShareDialog";
import { SignIn } from "@/components/SignIn";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { markRead } from "@/lib/seen";
import { useRouter } from "@tanstack/react-router";

/**
 * One of my books, at a part: the reader, a way back to the library, and the
 * book's other doings under More: share it, download it, its road so far,
 * remove it from the site (last, apart). What this device has read is kept
 * (lib/seen.ts): the library's "New", and where the book opens next.
 */
export function Chapter() {
  const t = useT();
  const router = useRouter();
  const { id, part } = useParams({ from: "/book/$id/$part" });
  const [dialog, setDialog] = useState<"share" | "export" | "remove" | null>(null);
  const { data, error, refetch } = useCharacterBook(Number(id));
  const latestAt = data?.character.latest?.at;
  const chapters = data?.character.chapters ?? 0;
  const onRead = useCallback((p: string) => markRead(Number(id), chapters, latestAt, p), [id, chapters, latestAt]);
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  const close = () => setDialog(null);
  return (
    <>
      <Reader
        character={data.character}
        book={data.book}
        part={part}
        hrefFor={(p) => `/book/${id}/${p}`}
        onRead={onRead}
        lead={
          <Link to="/library" className="ui flex items-center gap-1 rounded-md px-1.5 py-1.5 text-gold-bright hover:bg-gold/10" aria-label={t.nav.back}>
            <ChevronLeft className="size-5" aria-hidden />
            <span className="hidden md:inline">{t.nav.back}</span>
          </Link>
        }
        actions={
          <Menu
            label={t.book.more}
            icon={<MoreHorizontal className="size-5" aria-hidden />}
            items={[
              { label: t.book.share, icon: <Share2 className="size-4" aria-hidden />, onSelect: () => setDialog("share") },
              { label: t.book.download, icon: <Download className="size-4" aria-hidden />, onSelect: () => setDialog("export") },
              {
                label: t.book.road,
                icon: <MapIcon className="size-4" aria-hidden />,
                onSelect: () => void router.navigate({ to: "/book/$id/road", params: { id } }),
              },
              { label: t.book.remove, icon: <Trash2 className="size-4" aria-hidden />, onSelect: () => setDialog("remove"), danger: true },
            ]}
          />
        }
      />
      <PrintBook character={data.character} book={data.book} />
      <ShareDialog open={dialog === "share"} onClose={close} character={data.character} book={data.book} part={part} />
      <ExportDialog open={dialog === "export"} onClose={close} character={data.character} book={data.book} id={data.character.id} />
      <RemoveDialog open={dialog === "remove"} onClose={close} character={data.character} />
    </>
  );
}
