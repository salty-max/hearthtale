import { useT } from "@/lib/i18n";

/** Loading and error states, on a page of the book. */
export function Loading() {
  const t = useT();
  return <p className="mt-10 text-center text-lg italic text-parchment/70">{t.common.loading}</p>;
}

export function LoadError({ retry, message }: { retry?: () => void; message?: string }) {
  const t = useT();
  return (
    <div className="page mx-auto mt-10 max-w-md rounded-md px-6 py-8 text-center">
      <p className="text-lg">{message ?? t.common.loadError}</p>
      {retry && (
        <button onClick={retry} className="btn mt-4">
          {t.common.retry}
        </button>
      )}
    </div>
  );
}
