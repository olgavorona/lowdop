# Project Instructions For Codex

## Language

- Communicate with the user, plans, and planning mode in English.
- Keep technical docs, code, context docs, rules, and project instructions in English.
- Keep AI prompts in English.
- Write all documentation in English, including README files and user-facing guides.
- Never write documentation in Russian.

## Localization

- App Store descriptions must be direct translations of the English description, preserving its claims, sections, and lists.
- Never change App Store keywords.
- Use `content/localization/keys.json` as the canonical translation key registry. Reuse it for translation handoffs instead of reassembling keys from old CSVs.
- When app UI, story text, or narration sources change, run `python3 content-generator/export_language_handoff.py --sync-registry`, then `python3 content-generator/export_language_handoff.py --check-registry`. Include the registry update with the content change.
- Preserve existing key IDs and retired key identities. Do not renumber unchanged keys or reuse an old key for different source text.
- Export translation sheets with `python3 content-generator/export_language_handoff.py`; normal exports read the saved registry without scanning app content.
- Keep unreleased seasonal content on its separate branch. The current main-app registry includes Thanksgiving and excludes Christmas until its inclusion is requested.

## Behavior

- No filler or praise-heavy framing. Be direct.
- Ask the user before changing app behavior, controls, popups, drawing rules, collection requirements, or completion flow. Preserve existing behavior during visual and content changes unless the user explicitly approves a behavior change.
- Tests that change preferences or progress must use isolated storage and preserve the installed app's saved state.
- Ask questions as plain chat messages when needed.
- Use GitHub CI/CD for deployments. Do not use direct server access, container restarts, or similar operational actions except for emergency debugging of broken production.

## Planning

- Use a plan for multi-step tasks.
- If the user explicitly asks for delegation or parallel agent work, use sub-agents only for bounded non-overlapping tasks.

## Security

- Never ask the user to paste secrets into chat.
- Tell the user to store secrets in secure local config such as `.env` files or in CI/CD secrets such as GitHub Actions secrets.
- Ask before pushing, deploying, or making other external changes to shared remote systems.
- Keep secrets and local credentials out of git. Ignore files such as `.env`, `*.key`, `credentials.json`, and `secrets/` when relevant.
- Be cautious with external actions such as push, deploy, sending messages, or creating PRs. Ask before acting externally when uncertain.
