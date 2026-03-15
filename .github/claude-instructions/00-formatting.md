# Code Formatting Requirements

## CRITICAL: Run Prettier Before Every Commit

This project uses Prettier for code formatting. CI will reject any PR with unformatted code.

**Before EVERY `git commit`, you MUST run these commands in order:**

```bash
npm ci                    # Install dependencies (includes prettier)
npx prettier --write .    # Format all files
npm run format:check      # Verify formatting passes
```

If you skip formatting, CI will fail immediately on the "Check code formatting" step.
