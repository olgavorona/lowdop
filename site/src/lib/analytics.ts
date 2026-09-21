import { siteConfig } from "../data/site";

const providerToken = import.meta.env.PUBLIC_APPLE_PROVIDER_TOKEN?.trim();

export function appStoreUrl(campaign: string): string {
  if (!providerToken) {
    return siteConfig.appStoreUrl;
  }

  const url = new URL(siteConfig.appStoreUrl);
  url.searchParams.set("pt", providerToken);
  url.searchParams.set("ct", campaign.slice(0, 30));
  url.searchParams.set("mt", "8");
  return url.toString();
}
