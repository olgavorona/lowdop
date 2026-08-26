export type PrintableDifficulty = {
  label: string;
  href: string;
};

export type PrintableMaze = {
  title: string;
  slug: string;
  description: string;
  detail: string;
  preview: string;
  difficulties: PrintableDifficulty[];
};

export type PrintablePack = PrintableDifficulty;

export const fallMazePrintables = {
  title: "6 Free Printable Fall Mazes",
  eyebrow: "Denny's Maze printables",
  intro:
    "Printable fall mazes for quiet paper play: leaves, apples, corn, pumpkins, acorns and rainy puddles.",
  heroImage: "/printables/fall-mazes/hero-denny-yellow-raincoat.svg",
  assetBase: "/printables/fall-mazes",
  downloadPacks: ["easy", "medium", "hard"].map((difficulty) => ({
    label: difficulty[0].toUpperCase() + difficulty.slice(1),
    href: `/printables/fall-mazes/fall-mazes-${difficulty}.zip`
  })),
  mazes: [
    {
      title: "Leaf Pile Maze",
      slug: "leaf-pile",
      description:
        "A simple path maze where Denny follows the windy park trail to a leaf pile.",
      detail:
        "This one has no collectibles, so it is a good first page for kids who just want to trace the route.",
      preview: "/printables/fall-mazes/svg/leaf-pile-easy.svg"
    },
    {
      title: "Apple Basket Maze",
      slug: "apple-basket",
      description:
        "Denny finds apples along the orchard path and brings them to the basket.",
      detail:
        "A classic collect-and-finish maze with a clear fall task on every difficulty.",
      preview: "/printables/fall-mazes/svg/apple-basket-easy.svg"
    },
    {
      title: "Corn Maze",
      slug: "corn-maze",
      description:
        "A corn-shaped walled maze with ears of corn tucked inside the path.",
      detail:
        "This is the printable version for parents looking specifically for a corn maze activity.",
      preview: "/printables/fall-mazes/svg/corn-maze-easy.svg"
    },
    {
      title: "Pumpkin Patch Maze",
      slug: "pumpkin-patch",
      description:
        "A pumpkin-shaped walled maze where Denny collects pumpkins in the patch.",
      detail:
        "Good for autumn, Halloween-adjacent, or harvest-themed printable pages without making it spooky.",
      preview: "/printables/fall-mazes/svg/pumpkin-patch-easy.svg"
    },
    {
      title: "Acorn Shell Maze",
      slug: "acorn-trail",
      description:
        "A wider corridor maze inspired by the in-app shell-style levels, with acorns to collect.",
      detail:
        "This one feels different from the standard wall mazes and gives the set more variety.",
      preview: "/printables/fall-mazes/svg/acorn-trail-easy.svg"
    },
    {
      title: "Rainy Puddle Maze",
      slug: "rainy-walk",
      description:
        "It starts to rain, and Denny needs to get home dry while avoiding puddles.",
      detail:
        "An avoid-style maze instead of a collection maze, useful when you want a slightly different task.",
      preview: "/printables/fall-mazes/svg/rainy-walk-easy.svg"
    }
  ].map((maze) => ({
    ...maze,
    difficulties: ["easy", "medium", "hard"].map((difficulty) => ({
      label: difficulty[0].toUpperCase() + difficulty.slice(1),
      href: `/printables/fall-mazes/svg/${maze.slug}-${difficulty}.svg`
    }))
  }))
} satisfies {
  title: string;
  eyebrow: string;
  intro: string;
  heroImage: string;
  assetBase: string;
  downloadPacks: PrintablePack[];
  mazes: PrintableMaze[];
};
