import { createRootRoute, createRoute, createRouter } from "@tanstack/react-router";
import { Layout } from "@/components/Layout";
import { Book } from "@/routes/Book";
import { Chapter } from "@/routes/Chapter";
import { Home } from "@/routes/Home";
import { Library } from "@/routes/Library";
import { NotFound } from "@/routes/NotFound";
import { Pair } from "@/routes/Pair";
import { Settings } from "@/routes/Settings";
import { Hall } from "@/routes/Hall";
import { HallBook, Shared } from "@/routes/Shared";
import { Start } from "@/routes/Start";

const rootRoute = createRootRoute({ component: Layout, notFoundComponent: NotFound });
const homeRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: Home });
// ?part=…: which part of a whole shared book (a chapter's number, "prologue", "epitaph")
const partSearch = (s: Record<string, unknown>): { part?: string } => (typeof s.part === "string" ? { part: s.part } : {});
const sharedRoute = createRoute({ getParentRoute: () => rootRoute, path: "/s/$token", component: Shared, validateSearch: partSearch });
const hallRoute = createRoute({ getParentRoute: () => rootRoute, path: "/hall", component: Hall });
const hallBookRoute = createRoute({ getParentRoute: () => rootRoute, path: "/hall/$id", component: HallBook, validateSearch: partSearch });
const settingsRoute = createRoute({ getParentRoute: () => rootRoute, path: "/settings", component: Settings });
const startRoute = createRoute({ getParentRoute: () => rootRoute, path: "/start", component: Start });
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
  routeTree: rootRoute.addChildren([homeRoute, startRoute, settingsRoute, sharedRoute, hallRoute, hallBookRoute, libraryRoute, pairRoute, bookRoute, chapterRoute]),
  scrollRestoration: true,
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
