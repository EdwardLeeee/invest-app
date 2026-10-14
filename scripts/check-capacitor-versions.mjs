// Every @capacitor/* package is pinned to an exact version, and core, cli and ios
// share one release, which must also be the capacitor-swift-pm version that
// ios/App/CapApp-SPM/Package.swift pins (cap sync writes it; this catches a stale copy).
import { readFileSync } from "node:fs";

const read = (file) => readFileSync(new URL(file, import.meta.url), "utf8");
const pkg = JSON.parse(read("../package.json"));
const capacitor = Object.fromEntries(
  Object.entries({ ...pkg.dependencies, ...pkg.devDependencies }).filter(([name]) =>
    name.startsWith("@capacitor/"),
  ),
);
const errors = [];

for (const [name, spec] of Object.entries(capacitor)) {
  if (!/^\d+\.\d+\.\d+$/.test(spec)) errors.push(`${name} must be pinned to an exact version, not "${spec}"`);
}
const platform = ["core", "cli", "ios"].map((name) => capacitor[`@capacitor/${name}`]);
if (new Set(platform).size !== 1) errors.push(`core, cli and ios differ: ${platform.join(", ")}`);

const swiftPm = read("../ios/App/CapApp-SPM/Package.swift").match(
  /capacitor-swift-pm\.git", exact: "([^"]+)"/,
)?.[1];
if (swiftPm !== platform[0]) {
  errors.push(`Package.swift pins capacitor-swift-pm ${swiftPm ?? "nothing"}, package.json has ${platform[0]}; run npx cap sync ios`);
}

if (errors.length) {
  for (const error of errors) console.error(`::error::${error}`);
  process.exit(1);
}
console.log(`Capacitor pinned at ${platform[0]}: ${Object.keys(capacitor).join(", ")}`);
