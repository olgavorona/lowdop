export type BlogPost = {
  slug: string;
  title: string;
  date: string;
  description: string;
  excerpt: string;
};

export const blogPosts: BlogPost[] = [
  {
    slug: "why-i-bring-an-ipad-on-every-flight",
    title: "Why I Bring an iPad on Every Flight (Even Though I Limit Screen Time)",
    date: "2026-07-30",
    description:
      "A parent explains why an iPad can still belong in a toddler travel bag when screen time is limited, and which calm activities feel different on flights.",
    excerpt:
      "I spend a lot of energy trying to keep Leo away from over-stimulating screens, so it probably sounds strange that I never board a plane without an iPad in my bag. But the contradiction only exists if you assume all screen time is the same."
  },
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
