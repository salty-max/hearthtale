// The site's three faces (index.css): the titles, the book, the rest.
import "@fontsource/cinzel/600.css";
import "@fontsource/cinzel/700.css";
import "@fontsource-variable/eb-garamond";
import "@fontsource-variable/eb-garamond/wght-italic.css";
import "@fontsource-variable/inter";
import "@fontsource-variable/inter/wght-italic.css";
import "./index.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { router } from "@/router";
import { fitStandalone } from "@/lib/standalone";
import { inject } from "@vercel/analytics";

fitStandalone();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, retry: 1, refetchOnWindowFocus: true },
  },
});

// Visits counted without cookies (Vercel Web Analytics): never who.
inject();

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
