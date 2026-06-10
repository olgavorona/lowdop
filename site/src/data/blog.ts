export type BlogPost = {
  slug: string;
  title: string;
  date: string;
  description: string;
  excerpt: string;
};

export const blogPosts: BlogPost[] = [
  {
    slug: "i-spent-13-years-making-apps-impossible-to-put-down",
    title:
      "I Spent 13 Years Making Apps Impossible to Put Down. Now I'm Building the Opposite, for My Son.",
    date: "2026-06-10",
    description:
      "An iOS developer with 13 years of building retention-driven apps explains why she's now building the opposite — for her three-year-old son.",
    excerpt:
      "For thirteen years my job has been to make things hard to put down. I'm an iOS developer, and over that time I've shipped apps at companies whose names you'd recognize. Somewhere along the way I fell for product management too, and I picked up all the vocabulary: retention, time spent in app, engagement loops. I can talk about dopamine spikes the way other people talk about the weather."
  }
];

export function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC"
  });
}
