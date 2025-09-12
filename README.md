# Homelab

This repository manages docker-compose stacks and Komodo sync resources for a home lab.

Structure added:

- `stacks/` - docker-compose stacks (one folder per stack)
- `komodo/` - Komodo sync resources and templates
- `scripts/` - helper scripts (deploy helpers)

Quick start

1. To deploy a stack locally (docker-compose):

   ./scripts/deploy-stack.sh stacks/example-stack

2. To integrate with Komodo: add resources under `komodo/sync/` and push; Komodo will apply them via your configured instance.

Security

Keep secrets out of Git. Use `stacks/<stack>/env/` for `.env` files and add them to `.gitignore`.
# Homelab

This is my home lab repo that uses komodo to manage my home server.