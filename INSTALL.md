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
| `anthropic` | `ANTHROPIC_API_KEY` | [`claude-haiku-4-5`](https://platform.claude.com/docs/en/models/overview) |
| `openai` | `OPENAI_API_KEY` | [`gpt-5.6-luna`](https://developers.openai.com/api/docs/models/gpt-5.6-luna) |
| `gemini` | `GEMINI_API_KEY` | [`gemini-3.5-flash-lite`](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite) |
| `mistral` | `MISTRAL_API_KEY` | [`mistral-small-latest`](https://docs.mistral.ai/models/mistral-small-4-0-26-03) |
| `grok` | `XAI_API_KEY` | [`grok-4.3`](https://docs.x.ai/developers/models/grok-4.3) |
| `qwen` | `QWEN_API_KEY` | [`qwen3.8-flash`](https://www.alibabacloud.com/help/en/model-studio/models) |
| `ollama` | None | `llama3.2` |

Defaults favor fast, inexpensive command suggestions; reviewed September 14, 2026.
Haiku is still Anthropic's fastest tier, Mistral's alias tracks Small 4, and Grok
4.3 supports disabling reasoning. Newer Grok 4.6 requires reasoning, so it isn't
a drop-in replacement for this provider's `reasoning_effort: none` setting.

Gemini 3 uses [thinking levels](https://ai.google.dev/gemini-api/docs/generate-content/thinking)
and temperature `1.0`. Flash-Lite uses `MINIMAL` thinking, with a 1,024-token output
ceiling to leave room for reasoning. Gemini 3 Pro and newer Flash overrides use
`LOW`; Gemini 2.5 overrides keep the previous settings. Qwen 3.8 requests use
[`reasoning_effort: none`](https://www.alibabacloud.com/help/en/model-studio/qwen-api-via-openai-chat-completions)
to disable reasoning for short commands.

Explicit model settings in `~/.zshrc` take priority. Remove an old setting and open
a new shell to adopt the new default, or update it to the model in the table.

### Ollama

With Ollama installed and running, download the model:

```zsh
ollama pull llama3.2
```

Set `export ZSH_AI_PROVIDER="ollama"` in `~/.zshrc`. No API key needed;
requests stay on your machine when you use the local server.

The default stays `llama3.2` so existing installations don't need another download.
For a newer small model, try [Qwen 3.5 4B](https://ollama.com/library/qwen3.5:4b)
(a 3.4 GB download):

```zsh
ollama pull qwen3.5:4b
export ZSH_AI_OLLAMA_MODEL="qwen3.5:4b"
```

Put the model setting before the plugin loads in `~/.zshrc`. The Ollama provider
disables thinking for command suggestions.

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

Leave them unset to use the server's defaults. The built-in OpenAI model,
`gpt-5.6-luna`, uses `reasoning_effort: none` on the default OpenAI URL for fast
command suggestions. Set `ZSH_AI_OPENAI_REASONING_EFFORT` to override that choice;
custom endpoints and other models keep their server defaults when it is unset.

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
