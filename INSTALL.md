# Install and configure zsh-ai

You'll need zsh 5.0+, `curl`, and `perl`. Install `jq` for more reliable response
parsing; the plugin also works without it.

## Install

Pick one method. Put your [provider settings](#providers) in `~/.zshrc` **before**
the plugin loads, and keep API keys out of public dotfiles.

### Homebrew

```zsh
brew install matheusml/zsh-ai/zsh-ai
```

Then add to `~/.zshrc`:

```zsh
source "$(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh"
```

### Oh My Zsh

```zsh
git clone https://github.com/matheusml/zsh-ai "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-ai"
```

Add `zsh-ai` to your existing `plugins=(...)` list. Put provider settings above
the line that sources Oh My Zsh.

### Antigen

Add this after your provider settings and before `antigen apply`:

```zsh
antigen bundle matheusml/zsh-ai
```

### Manual

```zsh
git clone https://github.com/matheusml/zsh-ai ~/.zsh-ai
```

Then add `source ~/.zsh-ai/zsh-ai.plugin.zsh` to `~/.zshrc`.

## Providers

Anthropic is the default. Set its key, or choose another provider:

```zsh
export ZSH_AI_PROVIDER="openai"
export OPENAI_API_KEY="your-key-here"
```

| `ZSH_AI_PROVIDER` | API key variable | Default model |
| --- | --- | --- |
| `anthropic` | `ANTHROPIC_API_KEY` | `claude-haiku-4-5` |
| `openai` | `OPENAI_API_KEY` | `gpt-5.6-luna` |
| `gemini` | `GEMINI_API_KEY` | `gemini-3.5-flash-lite` |
| `mistral` | `MISTRAL_API_KEY` | `mistral-small-latest` |
| `grok` | `XAI_API_KEY` | `grok-4.3` |
| `qwen` | `QWEN_API_KEY` | `qwen3.8-flash` |
| `ollama` | None | `llama3.2` |

### Ollama

With Ollama installed and running, download the model:

```zsh
ollama pull llama3.2
```

Set `export ZSH_AI_PROVIDER="ollama"` in `~/.zshrc`. No API key needed;
requests stay on your machine when you use the local server.

### OpenAI-compatible endpoints

Point the OpenAI provider at a server that supports `/v1/chat/completions`:

```zsh
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
export ZSH_AI_OPENAI_MODEL="your-model-name"
```

For a remote server, use HTTPS. If it requires authentication, set
`ZSH_AI_OPENAI_API_KEY`; it takes priority over `OPENAI_API_KEY`.

These optional settings are passed through to servers that support them:

| Variable | API field | Values |
| --- | --- | --- |
| `ZSH_AI_OPENAI_THINKING` | `chat_template_kwargs.enable_thinking` | `0` or `1` |
| `ZSH_AI_OPENAI_REASONING_EFFORT` | `reasoning_effort` | Depends on the server and model, e.g. `none` or `low` |

Leave them unset to use server defaults. The default OpenAI model and URL use
`reasoning_effort: none` unless overridden.

`ZSH_AI_OPENAI_MAX_TOKENS` defaults to `256` and must be a positive integer.
Increase it if a reasoning model runs out of tokens before producing a command.

### Custom provider

Set `ZSH_AI_PROVIDER="custom"` and define `_zsh_ai_query_custom` before the plugin
loads. It receives the request as `$1` and must print only the generated command
to stdout. On failure, return a nonzero status or print an `Error:` message.

Use `_zsh_ai_build_context` to collect shell context and
`_zsh_ai_get_system_prompt "$context"` to build the same prompt as the bundled
providers. The function can call your own CLI or API.

## Configuration

Put overrides before the plugin loads in `~/.zshrc`.

### Models and URLs

Use `ZSH_AI_<PROVIDER>_MODEL` to change a model:

```zsh
export ZSH_AI_OLLAMA_MODEL="llama3.2"
```

Use `ZSH_AI_<PROVIDER>_URL` to change an endpoint (built-in providers except Gemini).
Ollama expects a base URL, such as `http://localhost:11434`, with no `/v1` suffix.
The others expect the full API URL. See [lib/config.zsh](lib/config.zsh) for defaults.

### Prompt preferences

Add instructions without replacing the built-in command and quoting rules:

```zsh
export ZSH_AI_PROMPT_EXTEND="Prefer rg over grep, fd over find, and bat over cat."
```

### Inline trigger

The default trigger is `# `, including the space. To change it:

```zsh
export ZSH_AI_TRIGGER=",,"
```

To use only `zsh-ai "..."` and leave comments alone:

```zsh
export ZSH_AI_COMMENT_HOOK=false
```

`off`, `no`, `0`, and `disabled` also turn the hook off, ignoring case.

## Try it

Open a new terminal. Type `# show current date` and press Enter. A command like
`date` should appear, ready to review and run. If you changed the trigger, use your
new prefix; if you disabled the hook, use `zsh-ai "show current date"` instead.

If that fails, see [troubleshooting](TROUBLESHOOTING.md).
