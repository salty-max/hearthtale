import type { CharacterBook, CharacterSummary, LinkCode, Me } from "@hearthtale/shared";
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

export function useLinkCode() {
  return useMutation({ mutationFn: () => call<LinkCode>("/api/link-codes", { method: "POST" }) });
}
