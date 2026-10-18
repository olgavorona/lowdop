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

export function softwareApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.productName,
    applicationCategory: "GameApplication",
    operatingSystem: "iOS",
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
  authorName
}: {
  title: string;
  description: string;
  datePublished: string;
  pathname: string;
  authorName: string;
}) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: title,
    description,
    datePublished,
    url: absoluteUrl(pathname),
    author: {
      "@type": "Person",
      name: authorName
    },
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
