# Install zsh-ai

Use Homebrew if you can. The other methods are for plugin managers and source installs.

Install the plugin files first, then choose a provider, then load `zsh-ai`. Provider exports must appear before the line that loads the plugin. Keep API keys out of public dotfiles.

## Install Method

### Homebrew

```bash
brew install matheusml/zsh-ai/zsh-ai
```

### Oh My Zsh

```bash
git clone https://github.com/matheusml/zsh-ai ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-ai
```

Add it to `plugins` later in `~/.zshrc`, after choosing a provider below:

```bash
plugins=(zsh-ai)
```

### Antigen

Add this later in `~/.zshrc`, after choosing a provider below and before `antigen apply`:

```bash
antigen bundle matheusml/zsh-ai
```

### Manual

```bash
git clone https://github.com/matheusml/zsh-ai ~/.zsh-ai
```

## Providers

Add one provider block to `~/.zshrc` before `zsh-ai` loads.

### Anthropic Claude

Default provider.

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

Key: [Anthropic Console](https://console.anthropic.com/account/keys)

### Ollama

Private when running on your own machine.

```bash
ollama pull llama3.2
export ZSH_AI_PROVIDER="ollama"
```

Download: [ollama.ai](https://ollama.ai/download)

### OpenAI

```bash
export ZSH_AI_PROVIDER="openai"
export OPENAI_API_KEY="your-api-key-here"
```

Key: [OpenAI](https://platform.openai.com/api-keys)

### Google Gemini

```bash
export ZSH_AI_PROVIDER="gemini"
export GEMINI_API_KEY="your-api-key-here"
```

Key: [Google AI Studio](https://makersuite.google.com/app/apikey)

### Mistral AI

```bash
export ZSH_AI_PROVIDER="mistral"
export MISTRAL_API_KEY="your-api-key-here"
```

Key: [Mistral Console](https://console.mistral.ai/)

### Grok

```bash
export ZSH_AI_PROVIDER="grok"
export XAI_API_KEY="your-api-key-here"
```

Key: [xAI Console](https://console.x.ai/)

### Qwen

```bash
export ZSH_AI_PROVIDER="qwen"
export QWEN_API_KEY="your-api-key-here"
```

Key: [DashScope](https://dashscope.console.aliyun.com/api-key)

## OpenAI-Compatible Endpoints

Use the OpenAI provider for LM Studio, LocalAI, llama.cpp, vLLM, LiteLLM, Perplexity, and similar APIs.

Local endpoint without auth:

```bash
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
export ZSH_AI_OPENAI_MODEL="your-model-name"
```

Use `http://` only for local endpoints. Use HTTPS for remote proxies or providers.

Remote proxy or provider with auth:

```bash
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="https://proxy.example.com/v1/chat/completions"
export ZSH_AI_OPENAI_MODEL="your-model-name"
export ZSH_AI_OPENAI_API_KEY="sk-your-proxy-key"
```

`ZSH_AI_OPENAI_API_KEY` takes priority over `OPENAI_API_KEY`.

`ZSH_AI_OPENAI_THINKING` sets the `chat_template_kwargs.enable_thinking` parameter, which is a non-standard API that controls thinking output for reasoning models with chat templates. Set to `0` to disable, `1` to enable, or leave unset for upstream defaults.

`ZSH_AI_OPENAI_REASONING_EFFORT` sets the `reasoning_effort` parameter for OpenAI-compatible endpoints that support it. For example, Groq supports `none` and `default` for `qwen/qwen3.6-27b`; set `none` to disable reasoning tokens. Common values are `none`, `default`, `minimal`, `low`, `medium`, and `high`; leave unset for upstream defaults.

`ZSH_AI_OPENAI_MAX_TOKENS` sets the maximum number of tokens for the response. Increase this value for reasoning models to prevent the thinking process from being cut off, leading to "Failed to generate command" or "Unable to parse response" errors.

## Custom Provider

Set `ZSH_AI_PROVIDER` to `custom` and define `_zsh_ai_query_custom` before `zsh-ai` loads. The function receives the natural-language query as its first argument. It must print only the generated command to standard output. If the provider fails, the function must print a message prefixed with `Error:` to the standard output, and/or return a non-zero status. This example uses the Codex CLI:

```zsh
export ZSH_AI_PROVIDER="custom"

_zsh_ai_query_custom() {
	local query="${1-}"
	local system_prompt_file response ret

	local system_prompt_file=$(mktemp)
	_zsh_ai_get_system_prompt "$(_zsh_ai_build_context)" > "$system_prompt_file"

	response=$(
		{
			codex exec \
				--ephemeral \
				--ignore-user-config \
				--skip-git-repo-check \
				--sandbox read-only \
				--model 'gpt-5.6-luna' \
				--config model_reasoning_effort=low \
				--config project_doc_max_bytes=0 \
				--config "model_instructions_file=\"$system_prompt_file\"" \
				-- "$query" \
				2>/dev/null
		} always {
			rm -f -- "$system_prompt_file"
		}
	)

	ret=$?
	if (( ret != 0 )); then
		echo "Error: Something went wrong while running codex."
		return $ret
	fi

	printf '%s\n' "$response"
}
```

Replace the model and CLI options with those supported by your Codex setup, or replace the function body entirely to call any local command or remote API.

## Load zsh-ai

Put the load line after your provider block in `~/.zshrc`.

Homebrew:

```bash
source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh
```

Manual install:

```bash
source ~/.zsh-ai/zsh-ai.plugin.zsh
```

Oh My Zsh users should keep the provider block above the line that loads Oh My Zsh. Antigen users should keep it above `antigen bundle matheusml/zsh-ai`.

## Verify

After installing and choosing a provider, reload your shell:

```bash
source ~/.zshrc
```

Then type this and press Enter:

```bash
# show current date and time
```

You should see a command like `date` appear in your prompt.

## Defaults

```bash
export ZSH_AI_PROVIDER="anthropic"
export ZSH_AI_ANTHROPIC_MODEL="claude-haiku-4-5"
export ZSH_AI_OPENAI_MODEL="gpt-5.4-mini"
export ZSH_AI_GEMINI_MODEL="gemini-2.5-flash"
export ZSH_AI_OLLAMA_MODEL="llama3.2"
export ZSH_AI_MISTRAL_MODEL="mistral-small-latest"
export ZSH_AI_GROK_MODEL="grok-4.3"
export ZSH_AI_QWEN_MODEL="qwen-flash"
```

Provider URLs are configurable too:

```bash
export ZSH_AI_ANTHROPIC_URL="https://api.anthropic.com/v1/messages"
export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
export ZSH_AI_OLLAMA_URL="http://localhost:11434"
export ZSH_AI_MISTRAL_URL="https://api.mistral.ai/v1/chat/completions"
export ZSH_AI_GROK_URL="https://api.x.ai/v1/chat/completions"
export ZSH_AI_QWEN_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
```

## Prompt Preferences

```bash
export ZSH_AI_PROMPT_EXTEND="Prefer rg over grep, fd over find, and bat over cat."
```

## Inline Trigger

By default, lines starting with `# ` are sent to the AI when you press Enter. Both
the trigger prefix and the hook itself are configurable:

```bash
# Change the trigger (default is "# "). For example, use ,, to start a query:
export ZSH_AI_TRIGGER=",,"

# Disable the inline hook entirely. Lines starting with "# " behave as normal
# shell comments again, and only the `zsh-ai "..."` command stays active.
# Useful when pasting code blocks that contain "# comment" lines.
export ZSH_AI_COMMENT_HOOK="false"
```

`ZSH_AI_COMMENT_HOOK` accepts `false`, `off`, `no`, `0`, or `disabled` (case
insensitive) to turn the hook off; any other value keeps it on.

## Requirements

- zsh 5.0+
- curl
- perl
- jq, optional

Install `jq` if JSON parsing fails:

```bash
brew install jq
```
