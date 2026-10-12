import js from "@eslint/js";
import tseslint from "typescript-eslint";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default tseslint.config(
  {
    ignores: [
      "**/dist/**",
      ".vercel/**",
      "**/dev-dist/**",
      "**/node_modules/**",
      "**/.turbo/**",
      "addon/**", // the WoW addon: Lua, checked by its own tests
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_", ignoreRestSiblings: true },
      ],
    },
  },
  {
    // Backend (Bun/Node) + shared package
    files: ["apps/api/**/*.ts", "packages/shared/**/*.ts", "scripts/**/*.ts"],
    languageOptions: { globals: { ...globals.node } },
  },
  {
    // The web app's plain scripts: one before the first paint, one in the service worker
    files: ["apps/web/public/theme.js"],
    languageOptions: { globals: { ...globals.browser } },
  },
  {
    files: ["apps/web/public/push-sw.js"],
    languageOptions: { globals: { ...globals.serviceworker } },
  },
  {
    // React SPA
    files: ["apps/web/**/*.{ts,tsx}"],
    languageOptions: { globals: { ...globals.browser } },
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  },
);
