import type { CapacitorConfig } from "@capacitor/cli";

// The web build is bundled into the binary (webDir), never loaded from server.url.
// The page's origin is capacitor://localhost, which the research room's backend
// allows cross-origin (INVEST_APP_ORIGINS) for GET only.
//
// No backgroundColor: Capacitor then paints the web view with the system
// background colour, so the app follows light and dark mode with no white flash.
const config: CapacitorConfig = {
  appId: "com.oraclelee.invest",
  appName: "個股研究室",
  webDir: "web",
};

export default config;
