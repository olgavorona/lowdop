import { execFileSync } from "node:child_process";
import { relative, resolve } from "node:path";

/** Last content commit date; pass an ISO date to override it for a page. */
export function getLastUpdated(sourcePath: string, override?: string): string {
  if (override) return override;

  const root = execFileSync("git", ["rev-parse", "--show-toplevel"], {
    cwd: process.cwd(),
    encoding: "utf8"
  }).trim();
  const absoluteSource = resolve(root, sourcePath);
  const relativeSource = relative(root, absoluteSource);
  const date = execFileSync("git", ["log", "-1", "--format=%cs", "--", relativeSource], {
    cwd: root,
    encoding: "utf8"
  }).trim();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new Error(`No git content date found for ${sourcePath}; provide a manual override.`);
  }
  return date;
}

export function formatLastUpdated(date: string): string {
  return new Date(`${date}T00:00:00Z`).toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC"
  });
}
