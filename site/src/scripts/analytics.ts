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

    const pageUrl = new URL(window.location.href);
    const attribution = {
      path: pageUrl.pathname,
      utm_source: pageUrl.searchParams.get("utm_source") || "",
      utm_medium: pageUrl.searchParams.get("utm_medium") || "",
      utm_campaign: pageUrl.searchParams.get("utm_campaign") || ""
    };

    const appStoreLink = target.closest<HTMLAnchorElement>("a[data-app-store-cta]");
    if (appStoreLink) {
      void telemetry.signal("website.appStoreClicked", {
        ...attribution,
        placement: appStoreLink.dataset.appStoreCta || "unknown",
        campaign: appStoreLink.dataset.appStoreCampaign || "unconfigured"
      });
    }

    const amazonLink = target.closest<HTMLAnchorElement>("a[data-amazon-cta]");
    if (amazonLink) {
      void telemetry.signal("website.amazonClicked", {
        ...attribution,
        placement: amazonLink.dataset.amazonCta || "unknown"
      });
    }

    const downloadLink = target.closest<HTMLAnchorElement>("a[download]");
    if (downloadLink) {
      const file = new URL(downloadLink.href).pathname;
      const format = file.split(".").pop()?.toLowerCase() || "unknown";
      void telemetry.signal("website.printableDownloadClicked", {
        ...attribution,
        file,
        format,
        kind: format === "zip" ? "archive" : "maze",
        placement: downloadLink.dataset.downloadPlacement || "unknown"
      });
    }
  });
}
