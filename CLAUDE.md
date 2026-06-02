# Agent Notes

This repo is a small zsh plugin that turns natural-language prompts into shell commands.

## Public Docs

- `README.md`: product pitch, quick install, usage
- `INSTALL.md`: install methods, providers, config
- `TROUBLESHOOTING.md`: setup and runtime issues
- `CONTRIBUTING.md`: contributor workflow

## Code Shape

- `zsh-ai.plugin.zsh`: loads modules
- `lib/config.zsh`: defaults and provider validation
- `lib/context.zsh`: directory, project, git, and OS context
- `lib/widget.zsh`: `# ...` comment flow
- `lib/utils.zsh`: prompt construction, provider routing, `zsh-ai`
- `lib/providers/`: provider modules

## Invariants

- shell only
- `jq` stays optional
- commands land in the prompt before execution
- test both `# ...` and `zsh-ai "..."`
- provider changes need tests and docs

## Tests

```bash
./run-tests.zsh
./run-tests.zsh tests/providers
zsh tests/config.test.zsh
```

CI runs ShellCheck, but the workflow currently does not fail on ShellCheck output.

## Provider Work

Update `lib/config.zsh`, the provider module, `tests/providers/`, `README.md`, and `INSTALL.md`. Cover API errors, empty responses, and parsing with and without `jq`.
