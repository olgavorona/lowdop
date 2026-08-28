export type PrintableDifficulty = {
  label: string;
  href: string;
  preview: string;
};

export type PrintableMaze = {
  title: string;
  originalTitle: string;
  slug: string;
  alt: string;
  description: string;
  preview: string;
  difficulties: PrintableDifficulty[];
};

export type PrintablePack = {
  label: string;
  href: string;
};

export const fallMazePrintables = {
  title: "6 Free Printable Fall Mazes for Kids",
  supportLine: "Ages 2-6 · 6 designs · Easy, Medium & Hard · Black-and-white PDFs",
  eyebrow: "Denny's Maze printables",
  intro:
    "Looking for free printable fall mazes for kids? This black-and-white PDF set includes six autumn-themed maze worksheets featuring leaves, apples, corn, pumpkins, acorns and rainy puddles. The mazes are designed for children around ages 2-6 and are available in Easy, Medium and Hard difficulty, so parents can choose a simple maze for a beginner or a more challenging path for a child who already enjoys maze puzzles.\n\nDownload individual mazes below or print the complete fall maze set. The thick maze lines and larger coloring-style illustrations make them simple, no-prep activities for quiet time at home, preschool or kindergarten, travel, restaurants, waiting rooms and rainy fall afternoons.",
  heroImage: "/printables/fall-mazes/hero-denny-yellow-raincoat.svg",
  assetBase: "/printables/fall-mazes",
  downloadPacks: ["easy", "medium", "hard"].map((difficulty) => ({
    label: difficulty[0].toUpperCase() + difficulty.slice(1),
    href: `/printables/fall-mazes/fall-mazes-${difficulty}.zip`
  })),
  mazes: [
    {
      title: "Fall Leaf Maze Printable",
      originalTitle: "Leaf Pile Maze",
      slug: "leaf-pile",
      alt: "Printable fall leaf maze for kids",
      description:
        "Help Denny follow the autumn trail to the leaf pile in this free printable fall leaf maze. The simpler version works well for younger children and first-time maze solvers, while Medium and Hard add more challenge.",
      preview: "/printables/fall-mazes/svg/leaf-pile-easy.svg"
    },
    {
      title: "Apple Maze Printable",
      originalTitle: "Apple Basket Maze",
      slug: "apple-basket",
      alt: "Printable apple maze for kids",
      description:
        "Help Denny collect the apples and find the basket in this free printable apple maze for kids. Choose Easy, Medium or Hard depending on how comfortable your child is with maze puzzles.",
      preview: "/printables/fall-mazes/svg/apple-basket-easy.svg"
    },
    {
      title: "Corn Maze Printable",
      originalTitle: "Corn Maze",
      slug: "corn-maze",
      alt: "Printable corn maze for kids",
      description:
        "Turn a classic fall corn maze into a quiet paper activity. Children guide Denny through the maze while following the path and finding the corn along the way.",
      preview: "/printables/fall-mazes/svg/corn-maze-easy.svg"
    },
    {
      title: "Pumpkin Maze Printable",
      originalTitle: "Pumpkin Patch Maze",
      slug: "pumpkin-patch",
      alt: "Printable pumpkin maze for kids",
      description:
        "Guide Denny through this printable pumpkin maze and collect pumpkins along the way. It works well as a fall, harvest or gentle non-spooky Halloween maze activity for young children.",
      preview: "/printables/fall-mazes/svg/pumpkin-patch-easy.svg"
    },
    {
      title: "Acorn Maze Printable",
      originalTitle: "Acorn Shell Maze",
      slug: "acorn-trail",
      alt: "Printable acorn maze for kids",
      description:
        "Follow the paths through this acorn-themed autumn maze and collect the acorns along the way. Choose a difficulty level to make the puzzle simpler or more challenging.",
      preview: "/printables/fall-mazes/svg/acorn-trail-easy.svg"
    },
    {
      title: "Rainy Puddle Maze Printable",
      originalTitle: "Rainy Puddle Maze",
      slug: "rainy-walk",
      alt: "Printable rainy puddle maze for kids",
      description:
        "Help Denny find the way home while avoiding the puddles. This fall maze adds a different problem-solving task instead of asking children to collect objects.",
      preview: "/printables/fall-mazes/svg/rainy-walk-easy.svg"
    }
  ].map((maze) => ({
    ...maze,
    difficulties: ["easy", "medium", "hard"].map((difficulty) => ({
      label: difficulty[0].toUpperCase() + difficulty.slice(1),
      href: `/printables/fall-mazes/pdf/${maze.slug}-${difficulty}.pdf`,
      preview: `/printables/fall-mazes/svg/${maze.slug}-${difficulty}.svg`
    }))
  }))
} satisfies {
  title: string;
  supportLine: string;
  eyebrow: string;
  intro: string;
  heroImage: string;
  assetBase: string;
  downloadPacks: PrintablePack[];
  mazes: PrintableMaze[];
};
