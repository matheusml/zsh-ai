# Working on zsh-ai

This is a zsh plugin. Generated commands must land in the prompt for review
before execution. Keep zsh 5.0+ support, `jq` optional, and runtime dependencies
limited to zsh, `curl`, and `perl`.

`zsh-ai.plugin.zsh` loads `lib/config.zsh`, context detection in `lib/context.zsh`,
provider modules in `lib/providers/`, prompt construction and the direct command
in `lib/utils.zsh`, and the Enter hook in `lib/widget.zsh`.

Run `./run-tests.zsh`; see [CONTRIBUTING.md](CONTRIBUTING.md) for focused runs and
test conventions. For behavior changes, check both `# ...` and `zsh-ai "..."`.
CI's ShellCheck step is advisory.

Provider changes need config, provider code, tests, and [INSTALL.md](INSTALL.md)
updates. Cover API errors, empty responses, and parsing with and without `jq`.

Keep the README short: what it does, a working example, quick setup. Put setup
details in INSTALL.md and fixes for common problems in TROUBLESHOOTING.md.
