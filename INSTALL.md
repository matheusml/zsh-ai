# Installation Guide

## Prerequisites

- ✅ zsh 5.0+ (you probably already have this)
- ✅ `curl` (already on macOS/Linux)
- ➕ `jq` (optional, for better reliability)

**Choose your AI provider:**
- **Anthropic Claude** (default): [Get API key](https://console.anthropic.com/account/keys)
- **Google Gemini**: [Get API key](https://makersuite.google.com/app/apikey)
- **OpenAI**: [Get API key](https://platform.openai.com/api-keys)
- **Ollama** (local): [Install Ollama](https://ollama.ai/download)

## Installation

### Homebrew (Recommended)

1. Run this

```bash
brew tap matheusml/zsh-ai
brew install zsh-ai
```

2. Add this to your `~/.zshrc`

```bash
source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh
```

3. Start a new terminal session.

### Antigen

1. Add the following to your `.zshrc`:

    ```sh
    antigen bundle matheusml/zsh-ai
    ```

2. Start a new terminal session.

### Oh My Zsh

1. Clone it
```bash
git clone https://github.com/matheusml/zsh-ai ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-ai
```

2. Add `zsh-ai` to your plugins list in `~/.zshrc`:

```bash
plugins=( 
    # other plugins...
    zsh-ai
)
```

3. Start a new terminal session.

### Manual Installation

1. Clone it
```bash
git clone https://github.com/matheusml/zsh-ai ~/.zsh-ai
```

2. Add it to your `~/.zshrc`
```bash
echo "source ~/.zsh-ai/zsh-ai.plugin.zsh" >> ~/.zshrc
```

3. Start a new terminal session.

### Setup

**Option 1: Anthropic Claude (default)**
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

**Option 2: Google Gemini**
```bash
export GEMINI_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="gemini"
```

**Option 3: OpenAI**
```bash
export OPENAI_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="openai"
# Optional: Change model (default is gpt-4o)
export ZSH_AI_OPENAI_MODEL="gpt-4o-mini"
```

**Option 4: Ollama (local models)**
```bash
# Run a model (e.g., 3.2)
ollama run llama3.2

# Configure zsh-ai to use Ollama
export ZSH_AI_PROVIDER="ollama"
```

Add to your `~/.zshrc` to make it permanent.

### Configuration

All configuration is done via environment variables with sensible defaults:

```bash
# Choose AI provider: "anthropic" (default), "gemini", "openai", or "ollama"
export ZSH_AI_PROVIDER="anthropic"

# Anthropic-specific settings
export ZSH_AI_ANTHROPIC_MODEL="claude-3-5-sonnet-20241022"  # (default)

# Gemini-specific settings
export ZSH_AI_GEMINI_MODEL="gemini-2.5-flash"  # (default)

# OpenAI-specific settings
export ZSH_AI_OPENAI_MODEL="gpt-4o"  # (default)

# Ollama-specific settings 
export ZSH_AI_OLLAMA_MODEL="llama3.2"  # (default)
export ZSH_AI_OLLAMA_URL="http://localhost:11434"  # (default)

# Custom system prompt (optional)
# Override the default system prompt with your own
export ZSH_AI_SYSTEM_PROMPT="You are a command line assistant that generates zsh commands. Always output only the raw command without explanations."
```

**That's it!** Most users won't need to change anything.

### Advanced Configuration

#### Custom System Prompt

You can customize the system prompt to change how the AI generates commands. This is useful for:
- Adding specific rules for your workflow
- Changing the output format
- Adding context about your environment

```bash
# Example: More verbose explanations
export ZSH_AI_SYSTEM_PROMPT="Generate zsh commands with brief inline comments explaining what they do."

# Example: Security-focused
export ZSH_AI_SYSTEM_PROMPT="Generate secure zsh commands. Always validate input, avoid rm -rf, and use safe defaults."

# Example: Specific to your stack
export ZSH_AI_SYSTEM_PROMPT="Generate zsh commands for a Node.js development environment. Prefer npm/yarn commands when applicable."
```

Note: The default prompt is optimized for generating clean, executable commands. Only customize if you have specific needs.