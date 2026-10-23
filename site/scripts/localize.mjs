import { readFile, readdir, mkdir, writeFile } from "node:fs/promises";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import * as parse5 from "parse5";

const siteRoot = fileURLToPath(new URL("../", import.meta.url));
const distRoot = join(siteRoot, "dist");
const siteUrl = "https://www.harmlessapp.com";
const extracting = process.argv.includes("--extract");
const locales = JSON.parse(await readFile(join(siteRoot, "src/data/locales.json"), "utf8"));
const translatedLocales = locales.filter(({ code }) => code !== "en");
const localeCodes = new Set(translatedLocales.map(({ code }) => code));
const translations = new Map();
if (!extracting) {
  for (const { code } of translatedLocales) {
    translations.set(code, JSON.parse(await readFile(join(siteRoot, `translations/${code}.json`), "utf8")));
  }
}
const strings = new Set();
const missing = new Map(translatedLocales.map(({ code }) => [code, new Set()]));
const textAttributes = new Set(["alt", "aria-label", "title", "placeholder"]);
const jsonTextKeys = new Set(["name", "headline", "description", "text", "title", "alt", "label"]);
const metaTextKeys = new Set(["description", "og:title", "og:description", "og:image:alt", "twitter:title", "twitter:description", "twitter:image:alt"]);

async function htmlFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (directory === distRoot && localeCodes.has(entry.name)) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await htmlFiles(path));
    else if (entry.name === "index.html") files.push(path);
  }
  return files.sort();
}

function normalized(value) {
  return value.trim().replace(/\s+/g, " ");
}

function translatable(value) {
  const key = normalized(value);
  return /[A-Za-z]/.test(key) && !/^https?:\/\//.test(key);
}

function translate(value, locale) {
  if (!translatable(value)) return value;
  const key = normalized(value);
  strings.add(key);
  if (extracting) return value;
  const translated = translations.get(locale.code)?.[key];
  if (typeof translated !== "string" || !translated.trim()) {
    missing.get(locale.code).add(key);
    return value;
  }
  return `${value.match(/^\s*/)?.[0] ?? ""}${translated}${value.match(/\s*$/)?.[0] ?? ""}`;
}

function attr(node, name) {
  return node.attrs?.find((item) => item.name === name);
}

function setAttr(node, name, value) {
  const existing = attr(node, name);
  if (existing) existing.value = value;
  else (node.attrs ??= []).push({ name, value });
}

function removeAttr(node, name) {
  if (node.attrs) node.attrs = node.attrs.filter((item) => item.name !== name);
}

function find(node, tagName) {
  if (node.tagName === tagName) return node;
  for (const child of node.childNodes ?? []) {
    const match = find(child, tagName);
    if (match) return match;
  }
  return null;
}

function localizedPath(code, path) {
  return code === "en" ? path : `/${code}${path}`;
}

function localizeUrl(value, locale) {
  if (value === siteUrl) return `${siteUrl}${localizedPath(locale.code, "/")}`;
  if (!value.startsWith(`${siteUrl}/`)) return value;
  const url = new URL(value);
  if (!paths.has(url.pathname)) return value;
  url.pathname = localizedPath(locale.code, url.pathname);
  return url.toString();
}

function localizeJson(value, locale, key = "") {
  if (Array.isArray(value)) return value.map((item) => localizeJson(item, locale, key));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([childKey, childValue]) => [childKey, localizeJson(childValue, locale, childKey)]));
  }
  if (typeof value !== "string") return value;
  if (["url", "item"].includes(key)) return extracting ? value : localizeUrl(value, locale);
  return jsonTextKeys.has(key) ? translate(value, locale) : value;
}

function visit(node, path, locale) {
  if (node.nodeName === "#text") {
    node.value = translate(node.value, locale);
    return;
  }
  if (attr(node, "translate")?.value === "no" || node.tagName === "style" || node.tagName === "svg") return;
  if (node.tagName === "script") {
    const type = attr(node, "type")?.value;
    if (type === "application/ld+json" || type === "application/json") {
      const content = node.childNodes?.find((child) => child.nodeName === "#text");
      if (content) {
        const value = localizeJson(JSON.parse(content.value), locale);
        if (!extracting) content.value = JSON.stringify(value).replace(/</g, "\\u003c");
      }
    }
    return;
  }

  for (const item of node.attrs ?? []) {
    if (textAttributes.has(item.name)) item.value = translate(item.value, locale);
    if (item.name === "content" && node.tagName === "meta") {
      const metaName = attr(node, "name")?.value ?? attr(node, "property")?.value;
      if (metaTextKeys.has(metaName)) item.value = translate(item.value, locale);
      if (locale && metaName === "og:url") item.value = `${siteUrl}${localizedPath(locale.code, path)}`;
      if (locale && metaName === "og:locale") item.value = locale.ogLocale;
    }
  }

  if (locale && node.tagName === "a") {
    const language = attr(node, "data-language-switch")?.value;
    if (language) {
      setAttr(node, "href", localizedPath(language, path));
      if (language === locale.code) setAttr(node, "aria-current", "page");
      else removeAttr(node, "aria-current");
    } else {
      const href = attr(node, "href");
      if (href?.value.startsWith("/") && !href.value.startsWith("//")) {
        const url = new URL(href.value, siteUrl);
        if (paths.has(url.pathname)) href.value = `${localizedPath(locale.code, url.pathname)}${url.search}${url.hash}`;
      }
    }
  }
  if (locale && node.tagName === "link" && attr(node, "rel")?.value === "canonical") {
    setAttr(node, "href", `${siteUrl}${localizedPath(locale.code, path)}`);
  }

  for (const child of node.childNodes ?? []) visit(child, path, locale);
}

function addAlternates(document, path) {
  const head = find(document, "head");
  for (const [language, href] of [
    ...locales.map(({ code }) => [code, `${siteUrl}${localizedPath(code, path)}`]),
    ["x-default", `${siteUrl}${path}`]
  ]) {
    const link = parse5.parseFragment(`<link rel="alternate" hreflang="${language}" href="${href}">`).childNodes[0];
    link.parentNode = head;
    head.childNodes.push(link);
  }
}

const files = await htmlFiles(distRoot);
const paths = new Set(files.map((file) => `/${relative(distRoot, dirname(file)).replaceAll("\\", "/")}/`.replace("//", "/")));

for (const file of files) {
  const path = `/${relative(distRoot, dirname(file)).replaceAll("\\", "/")}/`.replace("//", "/");
  const source = await readFile(file, "utf8");
  const document = parse5.parse(source);
  if (extracting) {
    visit(document, path, null);
    continue;
  }

  addAlternates(document, path);
  await writeFile(file, parse5.serialize(document));

  for (const locale of translatedLocales) {
    const localizedDocument = parse5.parse(source);
    setAttr(find(localizedDocument, "html"), "lang", locale.code);
    visit(localizedDocument, path, locale);
    addAlternates(localizedDocument, path);
    const destination = join(distRoot, locale.code, relative(distRoot, file));
    await mkdir(dirname(destination), { recursive: true });
    await writeFile(destination, parse5.serialize(localizedDocument));
  }
}

if (extracting) {
  process.stdout.write(`${JSON.stringify([...strings].sort((a, b) => a.localeCompare(b)), null, 2)}\n`);
} else {
  for (const [code, keys] of missing) {
    if (keys.size) {
      console.error(`Missing ${keys.size} ${code} translations:\n${[...keys].sort().join("\n")}`);
      process.exitCode = 1;
    } else {
      console.log(`Localized ${files.length} pages in ${code}.`);
    }
  }
}
