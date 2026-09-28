# Troubleshooting

Try `zsh-ai "show current date"` first; errors are easier to see there.

## Missing API key

Set the [key for your provider](INSTALL.md#providers) before the plugin loads in
`~/.zshrc`, then reload it with `source ~/.zshrc`. For the default provider:

```zsh
export ANTHROPIC_API_KEY="your-key-here"
```

Keep keys out of public dotfiles. [Claude Code](INSTALL.md#claude-code) and
[Ollama](INSTALL.md#ollama) work without one.

## The Claude Code CLI isn't found or fails

Check that `claude -p hello` works on its own. If the binary isn't on your `PATH`,
point at it directly:

```zsh
export ZSH_AI_CLAUDE_CODE_BIN="$HOME/.local/bin/claude"
```

If suggestions come back wrapped in your project's conventions, safe mode is off;
remove `ZSH_AI_CLAUDE_CODE_SAFE_MODE=false`. If your Claude Code credentials live
in `~/.claude/settings.json` rather than environment variables, safe mode skips
them, so pass the file back in:

```zsh
export ZSH_AI_CLAUDE_CODE_ARGS="--settings $HOME/.claude/settings.json"
```

## Ollama isn't reachable

Start it with `ollama serve` if it isn't running. In another terminal, run
`ollama pull llama3.2` to download the default model.

If it's already running, check the URL. It must be a base URL with no `/v1` suffix:

```zsh
export ZSH_AI_OLLAMA_URL="http://localhost:11434"
```

## The comment trigger doesn't work

Use `# ` with a space, or the prefix you set in `ZSH_AI_TRIGGER`. Check that
`ZSH_AI_COMMENT_HOOK` isn't disabled, then open a new terminal.

If `zsh-ai "list files"` works but the trigger doesn't, another plugin may be
replacing the Enter binding. Try loading zsh-ai after your other plugins.

## Pasted comments trigger a request

Choose a prefix you don't normally paste, such as `export ZSH_AI_TRIGGER=",,"`.
Or set `export ZSH_AI_COMMENT_HOOK=false` and use `zsh-ai "..."` directly.
Put the setting before the plugin loads, then open a new terminal.

## JSON parsing fails

Install `jq` with `brew install jq` or `sudo apt-get install jq`, then retry.

## Still stuck?

Run `zsh-ai` with no arguments to check the active provider. [Open an
issue](https://github.com/matheusml/zsh-ai/issues) with your OS, `zsh --version`,
provider, model, install method, and exact error. Remove any API keys before posting.
