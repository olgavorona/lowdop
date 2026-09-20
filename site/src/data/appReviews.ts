export const scoreDimensions = [
  { key: "calmness", label: "Calmness", short: "Lower sensory and attention intensity" },
  { key: "travel", label: "Travel", short: "Works reliably away from Wi-Fi" },
  { key: "contentValue", label: "Content value", short: "Breadth, depth, variety, and free access" },
  { key: "learningValue", label: "Learning value", short: "Meaningful, transferable skill use" },
  { key: "commercialExperience", label: "Commercial experience", short: "Transparent and low-pressure" }
] as const;

export type ScoreKey = typeof scoreDimensions[number]["key"];

export type AppReview = {
  slug: string;
  name: string;
  summary: string;
  scores: Record<ScoreKey, number>;
  learningMode: string;
  learningDomains: string[];
};

export const appReviews: AppReview[] = [
  { slug: "khan-academy-kids", name: "Khan Academy Kids", summary: "A broad, free learning library with strong skill practice and a clean commercial experience.", scores: { calmness: 6.4029, travel: 7.3333, contentValue: 10, learningValue: 8, commercialExperience: 10 }, learningMode: "Explicit academic and guided skill practice", learningDomains: ["Phonics", "early reading", "tracing", "early math", "logic", "spatial reasoning", "problem solving"] },
  { slug: "pok-pok", name: "Pok Pok", summary: "Open-ended digital toys with excellent offline use and little commercial pressure in the child flow.", scores: { calmness: 6.6067, travel: 10, contentValue: 7.1189, learningValue: 4.25, commercialExperience: 9 }, learningMode: "Mostly entertainment and open-ended play", learningDomains: ["Counting", "spatial reasoning", "creativity", "construction", "fine motor"] },
  { slug: "montessori-preschool", name: "Montessori Preschool", summary: "A large preschool catalog with substantial guided practice, balanced by a busier commercial model.", scores: { calmness: 5.5832, travel: 6.7667, contentValue: 9.2, learningValue: 7.875, commercialExperience: 5.95 }, learningMode: "Explicit academic practice", learningDomains: ["Phonics", "early reading", "early math", "logic", "spatial reasoning", "planning", "problem solving", "creativity"] },
  { slug: "thinkrolls", name: "Thinkrolls", summary: "Puzzle-led play with meaningful reasoning practice and good travel performance.", scores: { calmness: 4.1502, travel: 7.9, contentValue: 9.2, learningValue: 6.875, commercialExperience: 5.95 }, learningMode: "Constructive cognitive play", learningDomains: ["Early math", "logic", "spatial reasoning", "planning", "sequencing", "problem solving", "construction"] },
  { slug: "lingo", name: "Lingo", summary: "A deep activity catalog with moderate travel utility and relatively shallow sampled learning interactions.", scores: { calmness: 5.6034, travel: 6.9333, contentValue: 9.2, learningValue: 3.25, commercialExperience: 5.95 }, learningMode: "Guided skill practice", learningDomains: ["Early reading", "counting", "early math", "matching", "fine motor", "general knowledge"] },
  { slug: "sago-mini-school", name: "Sago Mini School", summary: "A varied preschool subscription with solid travel use and light representative learning demands.", scores: { calmness: 4.2408, travel: 7.5833, contentValue: 7.7, learningValue: 3.25, commercialExperience: 8.25 }, learningMode: "Mixed learning activities", learningDomains: ["Phonics", "early reading", "tracing", "counting", "matching", "spatial reasoning", "sequencing", "problem solving", "creativity"] },
  { slug: "sago-mini-world", name: "Sago Mini World", summary: "A broad pretend-play catalog whose sampled interactions emphasized entertainment over skill practice.", scores: { calmness: 4.2368, travel: 7.2333, contentValue: 9.2, learningValue: 0.625, commercialExperience: 5.95 }, learningMode: "Mostly entertainment", learningDomains: [] },
  { slug: "abc-mouse", name: "ABC Mouse", summary: "Very broad preschool content, but with high attention intensity and more friction around travel and purchases.", scores: { calmness: 3.1282, travel: 3.9, contentValue: 9.2, learningValue: 4.25, commercialExperience: 5.95 }, learningMode: "Explicit academic practice", learningDomains: ["Phonics", "early reading", "counting", "early math", "logic", "matching", "spatial reasoning", "problem solving", "general knowledge"] }
];

export const displayScore = (score: number) => score.toFixed(1);
