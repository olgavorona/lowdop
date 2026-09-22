import type { PrintableMaze, PrintablePack } from "./fallMazes";

const base = "/printables/halloween-mazes";

const mazeDefinitions = [
  {
    title: "Pumpkin Maze Printable",
    originalTitle: "Pumpkin Patch Maze",
    slug: "pumpkin-patch",
    alt: "Friendly printable Halloween pumpkin maze for kids",
    description:
      "Help Denny collect pumpkins and reach the smiling jack-o'-lantern in this free printable Halloween pumpkin maze. The friendly artwork keeps the activity seasonal without making it scary."
  },
  {
    title: "Jack-o'-Lantern Maze Printable",
    originalTitle: "Jack-o'-Lantern Maze",
    slug: "jack-o-lantern",
    alt: "Printable jack-o'-lantern maze for kids",
    description:
      "Follow the paths through this pumpkin-shaped printable maze and help Denny find the candy bucket. Choose Easy, Medium or Hard depending on how comfortable your child is with maze puzzles."
  },
  {
    title: "Spooky House Maze Printable",
    originalTitle: "Spooky House Maze",
    slug: "spooky-house",
    alt: "Friendly spooky house printable maze for kids",
    description:
      "Guide Denny through a house-shaped maze to the warm front door. This cozy, not-too-spooky Halloween printable turns the whole house silhouette into the puzzle."
  },
  {
    title: "Candy Corn Maze Printable",
    originalTitle: "Candy Corn Trail",
    slug: "candy-corn",
    alt: "Printable candy corn maze for kids",
    description:
      "Collect the candy corn along the path and help Denny carry it to the Halloween bucket. The simpler version works well for younger children, while Medium and Hard add more turns."
  },
  {
    title: "Moonlight Cat Maze Printable",
    originalTitle: "Moonlight Cat Maze",
    slug: "moonlight",
    alt: "Printable moonlight black cat maze for kids",
    description:
      "Follow a wide shell-style path, collect the stars and help black-cat Denny reach the moonlit hill. This design offers a different tracing challenge from the traditional wall mazes."
  },
  {
    title: "Ghost and Bat Maze Printable",
    originalTitle: "Ghost and Bat Dodge",
    slug: "ghost-bat-dodge",
    alt: "Printable Halloween maze with friendly ghosts and bats",
    description:
      "Practice planning a path by helping Denny avoid silly ghosts and sleepy bats on the way to the candy bucket. This Halloween maze adds a problem-solving task instead of asking children to collect objects."
  }
] as const;

export const halloweenMazePrintables = {
  title: "6 Free Printable Halloween Mazes for Kids",
  supportLine: "Ages 2-6 · 6 friendly designs · Easy, Medium & Hard · Color and black-and-white PDFs",
  themeName: "Halloween",
  includedMazes: ["Pumpkin Maze", "Jack-o'-Lantern Maze", "Spooky House Maze", "Candy Corn Maze", "Moonlight Cat Maze", "Ghost and Bat Maze"],
  intro:
    "Download six friendly Halloween maze worksheets featuring Denny dressed as a black cat, pumpkins, a jack-o'-lantern, candy corn, a spooky house, ghosts and bats. The pictures are playful rather than scary, with a real avoid-the-ghosts-and-bats challenge in the final maze.\n\nEvery design comes in Easy, Medium and Hard, with both full-color and printer-friendly black-and-white PDFs.",
  downloadPacks: ["easy", "medium", "hard"].map((difficulty) => ({
    label: difficulty[0].toUpperCase() + difficulty.slice(1),
    href: `${base}/halloween-mazes-${difficulty}.zip`
  })),
  colorDownloadPacks: ["easy", "medium", "hard"].map((difficulty) => ({
    label: difficulty[0].toUpperCase() + difficulty.slice(1),
    href: `${base}/halloween-mazes-color-${difficulty}.zip`
  })),
  mazes: mazeDefinitions.map((maze) => ({
    ...maze,
    preview: `${base}/svg/${maze.slug}-easy.svg`,
    difficulties: ["easy", "medium", "hard"].map((difficulty) => ({
      label: difficulty[0].toUpperCase() + difficulty.slice(1),
      href: `${base}/pdf/${maze.slug}-${difficulty}.pdf`,
      preview: `${base}/svg/${maze.slug}-${difficulty}.svg`,
      colorHref: `${base}/color/pdf/${maze.slug}-${difficulty}.pdf`,
      colorPreview: `${base}/color/svg/${maze.slug}-${difficulty}.svg`
    }))
  }))
} satisfies {
  title: string;
  supportLine: string;
  themeName: string;
  includedMazes: string[];
  intro: string;
  downloadPacks: PrintablePack[];
  colorDownloadPacks: PrintablePack[];
  mazes: PrintableMaze[];
};
