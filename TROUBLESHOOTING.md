# Troubleshooting

Start with the direct command so errors are easy to see:

```bash
zsh-ai "show current date"
```

## API Key Missing

```bash
zsh-ai: Warning: ANTHROPIC_API_KEY not set. Plugin will not function.
```

Set the key for your provider:

```bash
export ANTHROPIC_API_KEY="your-key"
```

For permanent setup, put the key above the `zsh-ai` load line in a private `~/.zshrc`.

Or switch to Ollama:

```bash
export ZSH_AI_PROVIDER="ollama"
```

If you use ChatGPT/Codex OAuth, no OpenAI API key is required. Configure Codex auth and sign in instead:

```bash
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_AUTH="codex"
zsh-ai-codex login
```

## ChatGPT/Codex Login Required

```bash
Run zsh-ai-codex login to sign in with ChatGPT/Codex.
```

Run:

```bash
zsh-ai-codex login
```

The command prints a URL and code. Open the URL on any device, enter the code, and return to the terminal.

Check auth state with:

```bash
zsh-ai-codex status
```

## ChatGPT/Codex Token Expired Or Revoked

```bash
Run zsh-ai-codex login to sign in again.
```

Run `zsh-ai-codex login` again. If the problem persists, sign out and sign in again:

```bash
zsh-ai-codex logout
zsh-ai-codex login
```

Codex OAuth tokens are stored at `~/.local/share/zsh-ai/auth.json`. The parent directory should be private and the file should be readable only by you:

```bash
chmod 700 ~/.local/share/zsh-ai
chmod 600 ~/.local/share/zsh-ai/auth.json
```

## Ollama Is Not Running

```bash
Error: Ollama is not running at http://localhost:11434
```

```bash
ollama serve
ollama pull llama3.2
```

## Nothing Happens With `#`

Reload your shell config:

```bash
source ~/.zshrc
```

Then test the explicit command:

```bash
zsh-ai "list files"
```

If that works, restart your terminal so the zle widget binding reloads.

## Pasting Code Breaks `#` Comments

If you paste code blocks that start with `# comment` lines, the inline hook can
intercept the first line and fire an unwanted query. Either change the trigger to
something you won't paste, or disable the hook and use `zsh-ai "..."` instead:

```bash
# Use a different trigger
export ZSH_AI_TRIGGER=",,"

# Or turn the inline hook off entirely
export ZSH_AI_COMMENT_HOOK="false"
```

See [INSTALL.md](INSTALL.md#inline-trigger) for details.

## JSON Parse Errors

Install `jq`:

```bash
brew install jq
```

Ubuntu or Debian:

```bash
sudo apt-get install jq
```

## Still Stuck

Check the active provider and model:

```bash
zsh-ai
```

Then open an issue with your OS, zsh version, provider, install method, and exact error:

https://github.com/matheusml/zsh-ai/issues
