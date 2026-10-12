import { crestOf } from "@/lib/wow";

/** A class's round crest in a gold ring, as the addon's pages show it. */
export function Crest({ token, size = 40, className = "" }: { token: string; size?: number; className?: string }) {
  const src = crestOf(token);
  if (!src) return <span aria-hidden className={`crest inline-block shrink-0 bg-leather-edge ${className}`} style={{ width: size, height: size }} />;
  return <img src={src} alt="" width={size} height={size} className={`crest shrink-0 ${className}`} loading="lazy" decoding="async" />;
}
