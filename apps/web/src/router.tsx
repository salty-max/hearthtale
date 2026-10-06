import { createRootRoute, createRoute, createRouter } from "@tanstack/react-router";
import { Layout } from "@/components/Layout";
import { Book } from "@/routes/Book";
import { Chapter } from "@/routes/Chapter";
import { Home } from "@/routes/Home";
import { Library } from "@/routes/Library";
import { NotFound } from "@/routes/NotFound";
import { Pair } from "@/routes/Pair";

const rootRoute = createRootRoute({ component: Layout, notFoundComponent: NotFound });
const homeRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: Home });
const libraryRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/library",
  component: Library,
  // ?signin=failed|cancelled: back from Battle.net without a session
  validateSearch: (s: Record<string, unknown>): { signin?: "failed" | "cancelled" } =>
    s.signin === "failed" || s.signin === "cancelled" ? { signin: s.signin } : {},
});
const pairRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/pair",
  component: Pair,
  validateSearch: (s: Record<string, unknown>): { code?: string } => (typeof s.code === "string" ? { code: s.code } : {}),
});
const bookRoute = createRoute({ getParentRoute: () => rootRoute, path: "/book/$id", component: Book });
const chapterRoute = createRoute({ getParentRoute: () => rootRoute, path: "/book/$id/$part", component: Chapter });

export const router = createRouter({
  routeTree: rootRoute.addChildren([homeRoute, libraryRoute, pairRoute, bookRoute, chapterRoute]),
  scrollRestoration: true,
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
