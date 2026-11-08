import assert from "node:assert/strict";
import { readFile, readdir, access } from "node:fs/promises";
import { join, dirname, relative } from "node:path";
import { fileURLToPath } from "node:url";
import * as parse5 from "parse5";
import { supportsPath, localizedPath } from "../src/lib/locales.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const dist = join(root, "dist");
const locales = JSON.parse(await readFile(join(root, "src/data/locales.json"), "utf8"));
const codes = new Set(locales.filter((locale) => locale.code !== "en").map((locale) => locale.code));
const origin = "https://www.harmlessapp.com";
const sitemap = await readFile(join(dist, "sitemap.xml"), "utf8");
const entries = [...sitemap.matchAll(/<url>(.*?)<\/url>/gs)].map((match) => match[1]);
const locations = entries.map((entry) => entry.match(/<loc>(.*?)<\/loc>/)[1]);
assert.equal(new Set(locations).size, locations.length, "Duplicate sitemap locations");

function all(node, predicate) {
  return [...(predicate(node) ? [node] : []), ...(node.childNodes ?? []).flatMap((child) => all(child, predicate))];
}
function attr(node, name) { return node.attrs?.find((item) => item.name === name)?.value; }
function text(node) { return node.nodeName === "#text" ? node.value : (node.childNodes ?? []).map(text).join(""); }

async function sourceFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (directory === dist && codes.has(entry.name)) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await sourceFiles(path));
    else if (entry.name === "index.html") files.push(path);
  }
  return files;
}

let checked = 0;
for (const file of await sourceFiles(dist)) {
  const path = `/${relative(dist, dirname(file))}/`.replace("//", "/");
  const available = locales.filter((locale) => supportsPath(locale, path));
  const source = parse5.parse(await readFile(file, "utf8"));
  const sourceImages = all(source, (node) => node.tagName === "img").map((node) => attr(node, "src"));
  for (const locale of available) {
    const url = `${origin}${localizedPath(locale, path)}`;
    const target = join(dist, localizedPath(locale, path), "index.html");
    const document = parse5.parse(await readFile(target, "utf8"));
    const html = all(document, (node) => node.tagName === "html")[0];
    assert.equal(attr(html, "lang"), locale.code, url);
    if (locale.code !== "en") assert.equal(attr(html, "dir"), locale.direction ?? "ltr", url);
    const links = all(document, (node) => node.tagName === "link");
    assert.equal(attr(links.find((node) => attr(node, "rel") === "canonical"), "href"), url);
    const alternates = links.filter((node) => attr(node, "rel") === "alternate");
    assert.equal(alternates.length, available.length + 1, `Alternate count: ${url}`);
    assert.equal(new Set(alternates.map((node) => attr(node, "hreflang"))).size, alternates.length);
    for (const language of available) {
      assert.equal(attr(alternates.find((node) => attr(node, "hreflang") === language.code), "href"), `${origin}${localizedPath(language, path)}`);
    }
    assert.equal(attr(alternates.find((node) => attr(node, "hreflang") === "x-default"), "href"), `${origin}${path}`);
    assert.ok(locations.includes(url), `Missing sitemap location: ${url}`);
    const entry = entries.find((value) => value.includes(`<loc>${url}</loc>`));
    for (const alternate of alternates) {
      assert.ok(entry.includes(`hreflang="${attr(alternate, "hreflang")}" href="${attr(alternate, "href")}"`), `Sitemap alternate missing: ${url}`);
    }
    const images = all(document, (node) => node.tagName === "img").map((node) => attr(node, "src"));
    assert.deepEqual(images, sourceImages, `Changed image source: ${url}`);
    for (const script of all(document, (node) => node.tagName === "script" && attr(node, "type") === "application/ld+json")) JSON.parse(text(script));
    for (const anchor of all(document, (node) => node.tagName === "a")) {
      const language = attr(anchor, "data-language-switch");
      if (language) {
        const choice = locales.find((item) => item.code === language);
        const destination = supportsPath(choice, path) ? path : "/";
        assert.equal(attr(anchor, "href"), localizedPath(choice, destination));
        assert.equal(attr(anchor, "aria-current"), language === locale.code ? "page" : undefined);
      }
      const href = attr(anchor, "href");
      if (href?.startsWith("/") && !href.startsWith("//")) {
        const pathname = new URL(href, origin).pathname;
        if (pathname.endsWith("/")) await access(join(dist, pathname, "index.html"));
      }
    }
    checked++;
  }
}
for (const location of locations) await access(join(dist, new URL(location).pathname, "index.html"));
for (const code of ["ar", "ko"]) {
  assert.ok(!locations.includes(`${origin}/${code}/blog/`), "Untranslated blog must not be indexed");
  await assert.rejects(access(join(dist, code, "blog/index.html")), "Do not generate English fallback pages under localized URLs");
}
assert.equal(checked, locations.length);
console.log(`Verified ${checked} pages: language/direction, canonical URLs, reciprocal HTML and sitemap alternates, JSON-LD, images, language switching, and internal links.`);
