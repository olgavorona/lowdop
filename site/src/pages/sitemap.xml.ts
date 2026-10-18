import type { APIRoute } from "astro";
import { siteConfig } from "../data/site";
import { absoluteUrl } from "../lib/seo";
import { appReviews } from "../data/appReviews";
import { getLastUpdated } from "../lib/freshness";

const pages = [
  ["/", "site/src/pages/index.astro"],
  ["/dennys-maze/", "site/src/pages/dennys-maze.astro"],
  ["/printables/", "site/src/pages/printables/index.astro"],
  ["/printables/fall/", "site/src/pages/printables/fall/index.astro"],
  ["/printables/halloween/", "site/src/pages/printables/halloween/index.astro"],
  ["/printables/thanksgiving/", "site/src/pages/printables/thanksgiving/index.astro"],
  ["/best-low-stimulation-apps-for-toddlers/", "site/src/pages/best-low-stimulation-apps-for-toddlers.astro"],
  ["/offline-toddler-apps/", "site/src/pages/offline-toddler-apps.astro"],
  ["/ratings/methodology/", "site/src/pages/ratings/methodology.astro"],
  ["/ratings/apps/", "site/src/pages/ratings/apps/index.astro"],
  ...appReviews.map((review) => [`/ratings/apps/${review.slug}/`, "site/src/data/appReviews.ts"]),
  ["/blog/", "site/src/pages/blog/index.astro"],
  ["/blog/what-actually-works-on-a-plane-with-a-3-year-old-after-10-flights/", "site/src/pages/blog/what-actually-works-on-a-plane-with-a-3-year-old-after-10-flights.astro"],
  ["/blog/why-i-bring-an-ipad-on-every-flight/", "site/src/pages/blog/why-i-bring-an-ipad-on-every-flight.astro"],
  ["/blog/i-spent-13-years-making-apps-impossible-to-put-down/", "site/src/pages/blog/i-spent-13-years-making-apps-impossible-to-put-down.astro"],
  ["/about/", "site/src/pages/about.astro"],
  ["/privacy/", "site/src/pages/privacy.astro"],
  ["/terms/", "site/src/pages/terms.astro"]
] as const;

export const GET: APIRoute = () => {
  const urls = pages
    .map(([path, sourcePath]) => {
      const lastmod = getLastUpdated(sourcePath);
      return `<url><loc>${absoluteUrl(path)}</loc><lastmod>${lastmod}</lastmod></url>`;
    })
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
