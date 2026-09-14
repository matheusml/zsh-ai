# Contributing

Small PRs are easiest to review. For a larger feature, open an issue first so we
can talk through it.

## Get started

```zsh
git clone https://github.com/matheusml/zsh-ai
cd zsh-ai
./run-tests.zsh
```

To try your changes, [configure a provider](INSTALL.md#providers), then run
`source ./zsh-ai.plugin.zsh` in an interactive zsh. Check both `# show git status`
and `zsh-ai "show git status"`.

## Tests and code

Run `./run-tests.zsh` for the full suite, `./run-tests.zsh tests/providers` for
providers, or `zsh tests/config.test.zsh` for one file.

Use the assertions and mocks in `tests/test_helper.zsh`. Wrap tests with
`run_test` and end each file with `finish_tests`. Provider tests should cover API
errors, empty responses, and parsing with and without `jq`.

Follow the existing zsh style, keep zsh 5.0+ working, and keep `jq` optional.
Avoid adding runtime dependencies. Update the install guide when config changes.

Before sending a PR, run the tests and try both ways of asking for a command if
you changed their behavior. Say what changed and how you checked it. Keep API
keys and local paths out of the diff.
