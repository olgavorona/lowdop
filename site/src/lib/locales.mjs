export function supportsPath(locale, path) {
  return !locale.paths || locale.paths.some((pattern) =>
    pattern.endsWith("*") ? path.startsWith(pattern.slice(0, -1)) : path === pattern
  );
}

export function localizedPath(locale, path) {
  return locale.code === "en" ? path : `/${locale.code}${path}`;
}
