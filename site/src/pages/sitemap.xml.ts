import type { APIRoute } from "astro";
import { siteConfig } from "../data/site";
import { absoluteUrl } from "../lib/seo";

const paths = [
  "/",
  "/dennys-maze/",
  "/best-low-stimulation-apps-for-toddlers/",
  "/blog/",
  "/blog/what-actually-works-on-a-plane-with-a-3-year-old-after-10-flights/",
  "/blog/why-i-bring-an-ipad-on-every-flight/",
  "/blog/i-spent-13-years-making-apps-impossible-to-put-down/",
  "/privacy/",
  "/terms/"
];

export const GET: APIRoute = () => {
  const urls = paths
    .map(
      (path) =>
        `<url><loc>${absoluteUrl(path)}</loc><changefreq>weekly</changefreq></url>`
    )
    .join("");

  const xml =
    `<?xml version="1.0" encoding="UTF-8"?>` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` +
    urls +
    `</urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "X-Site": siteConfig.siteName
    }
  });
};
