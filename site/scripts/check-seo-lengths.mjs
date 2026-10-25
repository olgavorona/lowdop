import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";

const outputDirectory = new URL("../dist/", import.meta.url);
const root = outputDirectory.pathname;
const warnings = [];

function decode(value) {
  return value
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">");
}

async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(path);
      continue;
    }
    if (!entry.isFile() || !entry.name.endsWith(".html")) continue;

    const html = await readFile(path, "utf8");
    if (!html.includes("<html")) continue;
    const title = html.match(/<title>(.*?)<\/title>/is)?.[1]?.trim();
    const description = html.match(/<meta\s+name="description"\s+content="([^"]*)"\s*\/?\s*>/i)?.[1];
    const language = html.match(/<html\s+lang="([^"]+)"/i)?.[1] ?? "en";
    const descriptionRange = language === "ja" ? [50, 110] : [120, 160];
    const page = `/${relative(root, path)}`;

    if (title) {
      const length = decode(title).length;
      if (length > 60) warnings.push(`${page}: title is ${length} characters (maximum 60)`);
    } else {
      warnings.push(`${page}: missing title`);
    }

    if (description === undefined) {
      warnings.push(`${page}: missing meta description`);
    } else {
      const length = decode(description).length;
      if (length < descriptionRange[0] || length > descriptionRange[1]) {
        warnings.push(`${page}: description is ${length} characters (expected ${descriptionRange[0]}–${descriptionRange[1]})`);
      }
    }
  }
}

try {
  await visit(root);
} catch (error) {
  console.error(`Could not read built site at ${root}: ${error.message}`);
  process.exitCode = 1;
}

if (warnings.length) {
  for (const warning of warnings) console.warn(`WARN ${warning}`);
  console.warn(`${warnings.length} SEO length warning(s).`);
} else if (!process.exitCode) {
  console.log("All built page titles and descriptions are within the requested lengths.");
}
