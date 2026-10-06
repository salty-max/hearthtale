import { createRootRoute, createRoute, createRouter } from "@tanstack/react-router";
import { Layout } from "@/components/Layout";
import { Home } from "@/routes/Home";
import { NotFound } from "@/routes/NotFound";

const rootRoute = createRootRoute({ component: Layout, notFoundComponent: NotFound });
const homeRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: Home });

export const router = createRouter({ routeTree: rootRoute.addChildren([homeRoute]) });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
