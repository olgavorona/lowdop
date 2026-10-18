import { siteConfig } from "../data/site";

export type MetaProps = {
  title: string;
  description: string;
  pathname: string;
  image?: string;
  imageAlt?: string;
  imageWidth?: number;
  imageHeight?: number;
  type?: "website" | "article";
};

export function absoluteUrl(pathname: string) {
  return new URL(pathname, siteConfig.siteUrl).toString();
}

export function buildMeta({
  title,
  description,
  pathname,
  image = siteConfig.defaults.ogImage,
  imageAlt = image === siteConfig.defaults.ogImage
    ? "Harmless Apps logo and description on a warm cream background"
    : `Illustration for ${title}`,
  imageWidth = image === siteConfig.defaults.ogImage ? 1200 : undefined,
  imageHeight = image === siteConfig.defaults.ogImage ? 630 : undefined,
  type = "website"
}: MetaProps) {
  return {
    title,
    description,
    canonical: absoluteUrl(pathname),
    image: absoluteUrl(image),
    imageAlt,
    imageWidth,
    imageHeight,
    type
  };
}

export function organizationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: siteConfig.organization.name,
    url: siteConfig.organization.url,
    logo: siteConfig.organization.logo,
    sameAs: siteConfig.organization.sameAs
  };
}

export function websiteSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: siteConfig.siteName,
    url: siteConfig.siteUrl
  };
}

export function authorSchema(authorName = "Olga Vorona") {
  return {
    "@type": "Person",
    name: authorName,
    url: absoluteUrl("/about/")
  };
}

export function breadcrumbListSchema(canonical: string, label: string) {
  if (new URL(canonical).pathname === "/") return null;
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: absoluteUrl("/") },
      { "@type": "ListItem", position: 2, name: label, item: canonical }
    ]
  };
}

export function editorialArticleSchema({
  title,
  description,
  pathname,
  dateModified,
  datePublished,
  image
}: {
  title: string;
  description: string;
  pathname: string;
  dateModified: string;
  datePublished?: string;
  image?: string;
}) {
  return {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: title,
    description,
    url: absoluteUrl(pathname),
    ...(image ? { image } : {}),
    ...(datePublished ? { datePublished } : {}),
    dateModified,
    author: authorSchema(),
    publisher: {
      "@type": "Organization",
      name: siteConfig.organization.name,
      url: siteConfig.organization.url
    }
  };
}

export function softwareApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.productName,
    applicationCategory: "GameApplication",
    operatingSystem: "iOS or iPadOS",
    isFamilyFriendly: true,
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD"
    },
    publisher: {
      "@type": "Organization",
      name: siteConfig.organization.name
    },
    url: absoluteUrl(siteConfig.productPath),
    downloadUrl: siteConfig.appStoreUrl,
    description:
      "A maze game for young kids designed to feel calmer, with no ads, no timers, and no flashing reward loops."
  };
}

export function blogPostingSchema({
  title,
  description,
  datePublished,
  pathname,
  authorName,
  dateModified,
  image
}: {
  title: string;
  description: string;
  datePublished: string;
  pathname: string;
  authorName: string;
  dateModified: string;
  image: string;
}) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: title,
    description,
    datePublished,
    dateModified,
    image,
    url: absoluteUrl(pathname),
    author: authorSchema(authorName),
    publisher: {
      "@type": "Organization",
      name: siteConfig.organization.name,
      url: siteConfig.organization.url
    }
  };
}

export function faqSchema(
  items: ReadonlyArray<{ question: string; answer: string }>
) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer
      }
    }))
  };
}
