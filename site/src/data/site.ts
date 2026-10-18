export const siteConfig = {
  brandName: "Harmless Apps",
  siteName: "Harmless Apps",
  siteUrl: "https://www.harmlessapp.com",
  appStoreUrl: "https://apps.apple.com/app/id6760107138",
  productName: "Denny's Maze",
  productPath: "/dennys-maze/",
  productTagline: "A calmer maze-book feeling on an iPad.",
  language: "en",
  organization: {
    name: "Harmless Apps",
    url: "https://www.harmlessapp.com",
    logo: "https://www.harmlessapp.com/og-default.png",
    sameAs: ["https://x.com/harmlessapps"]
    // TODO: Add verified LinkedIn and other public profile URLs when provided.
  },
  social: {
    twitterHandle: "@harmlessapps"
  },
  defaults: {
    title:
      "Harmless Apps | Calmer kids apps for screen time that feels less chaotic",
    description:
      "Harmless Apps makes calmer kids apps designed to feel less noisy, less rushed, and easier for parents to say yes to.",
    ogImage: "/og-default.png"
  }
} as const;

export type SiteConfig = typeof siteConfig;
