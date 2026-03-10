# Claude Workflows Integration Tests

Integration test suite for [claude-code-agentic-workflows](https://github.com/diranged/claude-code-agentic-workflows).

## Overview

This repository acts as a real consumer of the shared workflows, exercising end-to-end flows with real Claude invocations. Tests verify that:

- **@claude mention** triggers the responder and Claude responds
- **claude:design label** triggers the designer agent
- **Full auto-advance pipeline** (design → review → implement) creates a PR
- **Engineer managers** create dashboard issues and scan the codebase

## Setup Requirements

### GitHub App

A dedicated GitHub App ("Claude Workflows Integration Test") with:
- Issues: Read & Write
- Pull requests: Read & Write
- Contents: Read & Write
- Actions: Read

Install on this repository only.

### Secrets

| Secret | Description |
|--------|-------------|
| `CLAUDE_OAUTH_TOKEN` | Claude Code OAuth token for authentication |
| `INTEGRATION_APP_ID` | GitHub App ID |
| `INTEGRATION_APP_KEY` | GitHub App private key (PEM) |

### Main Repo Secret

The main repo (`diranged/claude-code-agentic-workflows`) needs:
- `INTEGRATION_TEST_PAT` — PAT with `repo` scope for `repository_dispatch`

## Running Tests

### Manual (workflow_dispatch)

```bash
gh workflow run integration-tests.yml -f tests=all
```

### Automatic (post-merge)

Tests auto-trigger when changes are pushed to `main` in the main repo via `repository_dispatch`.

### Individual Tests

```bash
gh workflow run integration-tests.yml -f tests=mention
gh workflow run integration-tests.yml -f tests=design
```

## Test Scenarios

| Test | Flow | Duration |
|------|------|----------|
| `mention` | @claude comment → response | ~2-3 min |
| `design` | claude:design → designer agent | ~5 min |
| `auto-advance` | design → review → implement pipeline | ~15-20 min |
| `engineer` | Engineer manager → dashboard creation | ~10-15 min |
