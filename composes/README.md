This folder contains docker-compose "stacks" (one stack per folder).

Layout:
- stacks/<stack-name>/docker-compose.yml  - main compose file for the stack
- stacks/<stack-name>/env/               - environment files or secrets (gitignored)
- stacks/<stack-name>/README.md          - stack-specific instructions

Guidelines:
- Keep each stack isolated in its folder.
- Use `.env` files for sensitive values; add them to `.gitignore`.
- Prefer using versioned images and pinned tags.
