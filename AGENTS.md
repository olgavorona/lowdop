# Project Instructions For Codex

## Language

- Communicate with the user, plans, and planning mode in English.
- Keep technical docs, code, context docs, rules, and project instructions in English.
- Keep AI prompts in English.
- Keep user-facing docs such as `README.md` in Russian unless the user asks otherwise.

## Behavior

- No filler or praise-heavy framing. Be direct.
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
