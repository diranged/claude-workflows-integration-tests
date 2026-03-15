# CLAUDE.md

## Project

Integration test repository for [claude-code-agentic-workflows](https://github.com/diranged/claude-code-agentic-workflows).

This repo mirrors what real consumers do — thin caller workflows that consume the shared workflows from the main repo. An orchestrator workflow creates test issues, applies labels, waits for triggered workflows, verifies outcomes, and cleans up.

## Structure

- `.github/workflows/claude-responder.yml` — Caller: @claude mentions
- `.github/workflows/claude-engineers.yml` — Caller: claude:\* labels
- `.github/workflows/claude-engineer-managers.yml` — Caller: engineer workflow_dispatch
- `.github/workflows/ci.yml` — Minimal CI (for CI retry testing)
- `.github/workflows/integration-tests.yml` — Orchestrator: runs all test scenarios
- `scripts/lib.sh` — Shared test utilities
- `scripts/test-*.sh` — Individual test scripts
- `scripts/run-tests.sh` — Main test runner

## Running Tests

Tests are triggered via:

1. `repository_dispatch` from the main repo (post-merge to main)
2. `workflow_dispatch` in this repo (manual ad-hoc runs)

## Required Secrets

- `CLAUDE_OAUTH_TOKEN` — Claude Code OAuth token
- `INTEGRATION_APP_ID` — GitHub App ID for triggering workflows
- `INTEGRATION_APP_KEY` — GitHub App private key
