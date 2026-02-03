# Installation Guide

## Quick Install (Homebrew)

The fastest way to get started:

```bash
# 1. Install
brew tap matheusml/zsh-ai && brew install zsh-ai

# 2. Add to your shell
echo 'source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh' >> ~/.zshrc

# 3. Set up a provider (see next section)
echo 'export ANTHROPIC_API_KEY="your-key-here"' >> ~/.zshrc

# 4. Restart your terminal
source ~/.zshrc
```

## Verify It Works

After installation, test that everything is set up correctly:

```bash
# Type this and press Enter:
# show current date and time
```

You should see a command like `date` appear in your prompt. If you see an error about missing API keys, check the provider setup below.

## Choose Your AI Provider

You need to configure one AI provider. Pick the one that works best for you:

### Anthropic Claude (Default)

The default provider. Great balance of quality and speed.

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

[Get your API key →](https://console.anthropic.com/account/keys)

### OpenAI

```bash
export OPENAI_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="openai"
```

[Get your API key →](https://platform.openai.com/api-keys)

### Google Gemini

```bash
export GEMINI_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="gemini"
```

[Get your API key →](https://makersuite.google.com/app/apikey)

### Ollama (Local & Free)

Run AI models locally on your machine. Completely free and private—no API keys needed.

```bash
# First, install and start Ollama
# Download from https://ollama.ai/download

# Pull a model
ollama pull llama3.2

# Configure zsh-ai
export ZSH_AI_PROVIDER="ollama"
```

[Download Ollama →](https://ollama.ai/download)

### Mistral AI

```bash
export MISTRAL_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="mistral"
```

[Get your API key →](https://console.mistral.ai/)

### Grok (X.AI)

```bash
export XAI_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="grok"
```

[Get your API key →](https://console.x.ai/)

### OpenAI-Compatible Servers

Works with LM Studio, LocalAI, llama.cpp, vLLM, and other local servers:

```bash
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
export ZSH_AI_OPENAI_MODEL="your-model-name"
# No API key needed for local servers
```

For proxies that require authentication (like LiteLLM), use `ZSH_AI_OPENAI_API_KEY` to avoid conflicts with your real `OPENAI_API_KEY`:

```bash
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="http://localhost:4000/v1/chat/completions"
export ZSH_AI_OPENAI_MODEL="gpt-4"
export ZSH_AI_OPENAI_API_KEY="sk-your-litellm-key"  # Won't interfere with OPENAI_API_KEY
```

### Perplexity

```bash
export OPENAI_API_KEY="pplx-your-api-key"
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_URL="https://api.perplexity.ai/chat/completions"
export ZSH_AI_OPENAI_MODEL="llama-3.1-sonar-small-128k-online"
```

---

**Remember:** Add these exports to your `~/.zshrc` to make them permanent.

## Alternative Installation Methods

### Oh My Zsh

```bash
# 1. Clone the plugin
git clone https://github.com/matheusml/zsh-ai ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-ai

# 2. Add to your plugins list in ~/.zshrc
plugins=(
    # other plugins...
    zsh-ai
)

# 3. Restart your terminal
```

### Antigen

Add to your `.zshrc`:

```bash
antigen bundle matheusml/zsh-ai
```

### Manual Installation

```bash
# 1. Clone the repo
git clone https://github.com/matheusml/zsh-ai ~/.zsh-ai

# 2. Add to your ~/.zshrc
echo "source ~/.zsh-ai/zsh-ai.plugin.zsh" >> ~/.zshrc

# 3. Restart your terminal
```

## Configuration Reference

All settings with their default values:

```bash
# Provider selection
export ZSH_AI_PROVIDER="anthropic"  # anthropic, openai, gemini, ollama, mistral, grok

# Anthropic
export ZSH_AI_ANTHROPIC_MODEL="claude-haiku-4-5"
export ZSH_AI_ANTHROPIC_URL="https://api.anthropic.com/v1/messages"

# OpenAI
export ZSH_AI_OPENAI_MODEL="gpt-4o"
export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
export ZSH_AI_OPENAI_API_KEY=""  # Optional: override OPENAI_API_KEY for proxies

# Gemini
export ZSH_AI_GEMINI_MODEL="gemini-2.5-flash"

# Ollama
export ZSH_AI_OLLAMA_MODEL="llama3.2"
export ZSH_AI_OLLAMA_URL="http://localhost:11434"

# Mistral
export ZSH_AI_MISTRAL_MODEL="mistral-small-latest"
export ZSH_AI_MISTRAL_URL="https://api.mistral.ai/v1/chat/completions"

# Grok
export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"
export ZSH_AI_GROK_URL="https://api.x.ai/v1/chat/completions"
```

## Advanced Configuration

### Custom Prompt Extensions

Customize the AI's behavior with your own instructions:

```bash
# Prefer modern CLI tools
export ZSH_AI_PROMPT_EXTEND="Always prefer ripgrep (rg) over grep, fd over find, and bat over cat."

# Project-specific instructions
export ZSH_AI_PROMPT_EXTEND="This is a Rails project. Use bundle exec for all ruby commands."

# Multiple preferences
export ZSH_AI_PROMPT_EXTEND="Additional preferences:
- Use GNU coreutils commands when available
- Prefer one-liners over scripts
- Always add the -v flag for verbose output"
```

Your extension is added to the core prompt, so the AI still follows all essential command generation rules.

## Prerequisites

For reference, here's what you need:

- **zsh 5.0+** (you probably already have this)
- **curl** (already on macOS/Linux)
- **jq** (optional, for better JSON parsing reliability)

Install jq if you run into JSON parsing issues:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```
