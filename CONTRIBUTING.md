# Contributing

Thanks for helping with `zsh-ai`. Small, focused PRs are easiest to review.

## Quick Path

```bash
git clone https://github.com/matheusml/zsh-ai
cd zsh-ai
./run-tests.zsh
```

After configuring a provider, run a manual check:

```bash
source zsh-ai.plugin.zsh
zsh-ai "show git status"
```

## Good PRs

- bug fixes
- provider fixes or new provider support
- better command generation behavior
- clearer setup or usage docs
- tests for existing edge cases

Open an issue first for larger features.

## Tests

```bash
./run-tests.zsh
./run-tests.zsh tests/providers
zsh tests/config.test.zsh
```

Tests live in `tests/`. Provider tests live in `tests/providers/`. Use `tests/test_helper.zsh` for assertions and mocks. Run each test with `run_test` and end test files with `finish_tests`.

Provider changes should cover:

- API errors
- empty responses
- parsing with `jq`
- parsing without `jq`
- docs updates when config changes

## Style

- follow the existing zsh patterns
- keep functions small
- keep provider code explicit
- preserve older zsh support
- do not add Node, Python, or another runtime dependency
- keep `jq` optional

## PR Checklist

- `./run-tests.zsh` passes
- `# ...` comment flow tested manually
- `zsh-ai "..."` tested manually
- no API keys or local paths committed
- PR description says what changed and how it was tested
