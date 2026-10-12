// The game's three faces, free (index.css): titles, the rest, numbers; and the
// reader's "Book" typeface.
import "@fontsource/almendra-sc";
import "@fontsource/proza-libre/400.css";
import "@fontsource/proza-libre/400-italic.css";
import "@fontsource/proza-libre/500.css";
import "@fontsource-variable/archivo-narrow";
import "@fontsource-variable/eb-garamond";
import "@fontsource-variable/eb-garamond/wght-italic.css";
import "./index.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { router } from "@/router";
import { fitStandalone } from "@/lib/standalone";

fitStandalone();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, retry: 1, refetchOnWindowFocus: true },
  },
});

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
);

// Fade the boot splash out once the shell has painted.
requestAnimationFrame(() => {
  const s = document.getElementById("splash");
  if (!s) return;
  s.classList.add("splash-hide");
  setTimeout(() => s.remove(), 400);
});
