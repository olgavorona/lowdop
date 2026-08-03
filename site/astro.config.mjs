import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://www.harmlessapp.com",
  output: "static",
  build: {
    format: "directory"
  }
});
