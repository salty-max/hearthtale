import type { CharacterBook, CharacterSummary, HallEntry, LinkCode, Me, Share, SharedBook } from "@hearthtale/shared";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

export class NotFound extends Error {}
export class NotSignedIn extends Error {}

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { ...init, headers: { accept: "application/json", ...init?.headers } });
  if (res.status === 404) throw new NotFound(path);
  if (res.status === 401) throw new NotSignedIn(path);
  if (!res.ok) throw new Error(`${path}: ${res.status}`);
  return (await res.json()) as T;
}
const noRetryOn = (count: number, err: unknown) => !(err instanceof NotFound || err instanceof NotSignedIn) && count < 1;

export function useMe() {
  return useQuery({ queryKey: ["me"], queryFn: () => call<Me | null>("/api/me"), staleTime: 5 * 60_000 });
}

export function useLibrary(enabled: boolean) {
  return useQuery({ queryKey: ["library"], queryFn: () => call<CharacterSummary[]>("/api/library"), enabled, retry: noRetryOn });
}

export function useCharacterBook(id: number) {
  return useQuery({ queryKey: ["character", id], queryFn: () => call<CharacterBook>(`/api/characters/${id}`), retry: noRetryOn });
}

/** After signing in or out: everything account-bound is fetched again. */
function useAccountChange() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries();
}

export function useSignOut() {
  const changed = useAccountChange();
  return useMutation({ mutationFn: () => call<{ ok: true }>("/api/auth/logout", { method: "POST" }), onSuccess: changed });
}

/** Local development only: the test account, which owns the test characters. */
export function useTestSignIn() {
  const changed = useAccountChange();
  return useMutation({ mutationFn: () => call<{ ok: true }>("/api/auth/test", { method: "POST" }), onSuccess: changed });
}

/** Is this pairing code waiting for a confirmation? */
export function usePairing(code: string) {
  return useQuery({ queryKey: ["pair", code], queryFn: () => call<{ pending: boolean }>(`/api/companion/pair/${encodeURIComponent(code)}`) });
}

export function useConfirmPairing() {
  return useMutation({
    mutationFn: (code: string) => call<{ ok: true }>("/api/companion/pair/confirm", { method: "POST", body: JSON.stringify({ code }), headers: { "content-type": "application/json" } }),
  });
}

/** Removing one of my books from the site (its uploads then wait for a new link code). */
export function useRemoveBook(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => call<{ ok: true }>(`/api/characters/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.removeQueries({ queryKey: ["character", id] });
      void qc.invalidateQueries({ queryKey: ["library"] });
      void qc.invalidateQueries({ queryKey: ["hall"] });
    },
  });
}

export function useLinkCode() {
  return useMutation({ mutationFn: () => call<LinkCode>("/api/link-codes", { method: "POST" }) });
}

// ── sharing ─────────────────────────────────────────────────────────────────
const json = (body: unknown): RequestInit => ({ body: JSON.stringify(body), headers: { "content-type": "application/json" } });

export function useShares(id: number) {
  return useQuery({ queryKey: ["shares", id], queryFn: () => call<Share[]>(`/api/characters/${id}/shares`), retry: noRetryOn });
}

export function useCreateShare(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (part?: string) => call<Share>(`/api/characters/${id}/shares`, { method: "POST", ...json({ part }) }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["shares", id] }),
  });
}

export function useRevokeShare(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (token: string) => call<{ ok: true }>(`/api/shares/${encodeURIComponent(token)}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["shares", id] }),
  });
}

export function useSetInHall(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (inHall: boolean) => call<{ ok: true }>(`/api/characters/${id}/hall`, { method: "PUT", ...json({ inHall }) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["character", id] });
      void qc.invalidateQueries({ queryKey: ["hall"] });
    },
  });
}

export function useShared(token: string) {
  return useQuery({ queryKey: ["shared", token], queryFn: () => call<SharedBook>(`/api/shared/${encodeURIComponent(token)}`), retry: noRetryOn });
}

export function useHall() {
  return useQuery({ queryKey: ["hall"], queryFn: () => call<HallEntry[]>("/api/hall") });
}

export function useHallBook(id: number) {
  return useQuery({ queryKey: ["hall", id], queryFn: () => call<SharedBook>(`/api/hall/${id}`), retry: noRetryOn });
}
