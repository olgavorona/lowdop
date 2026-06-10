export const siteConfig = {
  brandName: "Harmless Apps",
  siteName: "Harmless Apps",
  siteUrl: "https://harmlessapp.com",
  appStoreUrl: "https://apps.apple.com/ca/app/dennys-maze/id6760107138",
  productName: "Denny's Maze",
  productPath: "/dennys-maze/",
  productTagline: "A calmer maze-book feeling on an iPad.",
  language: "en",
  organization: {
    name: "Harmless Apps",
    url: "https://harmlessapp.com",
    logo: "https://harmlessapp.com/og-default.svg",
    sameAs: []
  },
  social: {
    twitterHandle: "@harmlessapps"
  },
  defaults: {
    title:
      "Harmless Apps | Calmer kids apps for screen time that feels less chaotic",
    description:
      "Harmless Apps makes calmer kids apps designed to feel less noisy, less rushed, and easier for parents to say yes to.",
    ogImage: "/og-default.svg"
  }
} as const;

export type SiteConfig = typeof siteConfig;
