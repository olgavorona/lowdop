import TelemetryDeck from "@telemetrydeck/sdk";

const appID = import.meta.env.PUBLIC_TELEMETRYDECK_WEB_APP_ID?.trim();
const namespace = import.meta.env.PUBLIC_TELEMETRYDECK_NAMESPACE?.trim();

class NavigationSafeTelemetryDeck extends TelemetryDeck {
  override _post(body: unknown): Promise<Response> {
    return fetch(this.target, {
      method: "POST",
      mode: "cors",
      keepalive: true,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
  }
}

if (appID && namespace) {
  const storageKey = "harmless-analytics-session";
  let clientUser = sessionStorage.getItem(storageKey);

  if (!clientUser) {
    clientUser = crypto.randomUUID();
    sessionStorage.setItem(storageKey, clientUser);
  }

  const telemetry = new NavigationSafeTelemetryDeck({
    appID,
    clientUser,
    target: `https://nom.telemetrydeck.com/v2/namespace/${encodeURIComponent(namespace)}/`
  });

  document.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;

    const link = target.closest<HTMLAnchorElement>("a[data-app-store-cta]");
    if (!link) return;

    const pageUrl = new URL(window.location.href);
    void telemetry.signal("website.appStoreClicked", {
      path: pageUrl.pathname,
      placement: link.dataset.appStoreCta || "unknown",
      campaign: link.dataset.appStoreCampaign || "unconfigured",
      utm_source: pageUrl.searchParams.get("utm_source") || "",
      utm_medium: pageUrl.searchParams.get("utm_medium") || "",
      utm_campaign: pageUrl.searchParams.get("utm_campaign") || ""
    });
  });
}
