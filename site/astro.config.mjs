import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://harmlessapp.com",
  output: "static",
  build: {
    format: "directory"
  }
});
