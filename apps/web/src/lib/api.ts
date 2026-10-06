import type { CharacterBook, CharacterSummary } from "@hearthtale/shared";
import { useQuery } from "@tanstack/react-query";

export class NotFound extends Error {}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: { accept: "application/json" } });
  if (res.status === 404) throw new NotFound(path);
  if (!res.ok) throw new Error(`${path}: ${res.status}`);
  return (await res.json()) as T;
}

export function useCharacters() {
  return useQuery({ queryKey: ["characters"], queryFn: () => get<CharacterSummary[]>("/api/characters") });
}

export function useCharacterBook(id: number) {
  return useQuery({
    queryKey: ["character", id],
    queryFn: () => get<CharacterBook>(`/api/characters/${id}`),
    retry: (count, err) => !(err instanceof NotFound) && count < 1,
  });
}
