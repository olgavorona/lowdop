import type { APIRoute } from "astro";
import { getLastUpdated } from "../lib/freshness";
import { siteConfig } from "../data/site";

const pages = [
  ["Denny’s Maze", "/dennys-maze/", "A quiet, paper-like maze app for young children that works offline."],
  ["Low-stimulation ratings", "/best-low-stimulation-apps-for-toddlers/", "A comparison of kids apps by sounds, animations, rewards, brightness and calm score."],
  ["Offline ratings", "/offline-toddler-apps/", "Results from testing toddler apps without Wi-Fi and after online setup."],
  ["Methodology", "/ratings/methodology/", "The measurement framework and scoring rules used in app reviews."],
  ["Printables", "/printables/", "Free seasonal maze printables for children."],
  ["Blog", "/blog/", "Olga Vorona’s writing about kids apps, screen time and family travel."],
  ["About Olga Vorona", "/about/", "About the iOS developer and creator of Harmless Apps and Denny’s Maze."]
] as const;

const lastUpdated = getLastUpdated("site/src/pages/llms.txt.ts");
const content = `# Harmless Apps

Harmless Apps reviews and builds children’s digital products with attention to calm design, learning value, offline use, and parent trust.

## About

Harmless Apps is a kids app review site by Olga Vorona, an iOS developer with 13 years of experience, a mother, and the creator of Harmless Apps and Denny’s Maze. Its comparisons distinguish recorded methodology testing from editorial estimates and disclose that Olga makes Denny’s Maze.

## Key pages

${pages.map(([label, path, description]) => `- [${label}](${siteConfig.siteUrl}${path}) — ${description}`).join("\n")}

## Queries this site answers

**What is Denny’s Maze?** A quiet, paper-like maze activity for toddlers and preschoolers, with three free mazes, no ads, and offline play after installation.

**Does Denny’s Maze need Wi-Fi?** No. The app works offline once installed.

**How are kids apps compared for low stimulation?** The comparison scores sounds, animations, rewards, and brightness; lab-tested scores use recorded gameplay and the published methodology.

**What does the offline app guide test?** It checks apps on a fresh install without internet and again after online setup, including what content remains available offline.

**Are there free printable mazes?** Yes. The printables collection includes free seasonal maze activities, including fall, Halloween, and Thanksgiving pages.

**How does Harmless Apps handle its Denny’s Maze conflict of interest?** The site discloses that Olga makes the app and says the conflict is mitigated with standard testing metrology, recorded evidence, consistent scoring, and human confirmation.

Last updated: ${lastUpdated}
`;

export const GET: APIRoute = () => new Response(content, {
  headers: { "Content-Type": "text/plain; charset=utf-8" }
});
