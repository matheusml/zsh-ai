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
export ZSH_AI_OPENAI_URL="https://your-local-openai/v1/completions"
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
export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions" # (default)


# Ollama-specific settings 
export ZSH_AI_OLLAMA_MODEL="llama3.2"  # (default)
export ZSH_AI_OLLAMA_URL="http://localhost:11434"  # (default)

# Advanced: Extend the AI prompt with custom instructions
# This adds to the existing prompt without replacing it
export ZSH_AI_PROMPT_EXTEND="Always prefer modern CLI tools like ripgrep, fd, and bat."
```

**That's it!** Most users won't need to change anything.

### Advanced Configuration

#### Custom Prompt Extensions

You can extend the AI's system prompt with your own instructions using `ZSH_AI_PROMPT_EXTEND`. This is useful for:
- Adding preferences for specific tools
- Customizing behavior for your workflow
- Providing project-specific context

```bash
# Example: Prefer modern CLI alternatives
export ZSH_AI_PROMPT_EXTEND="Always prefer ripgrep (rg) over grep, fd over find, and bat over cat."

# Example: Add multiple rules
export ZSH_AI_PROMPT_EXTEND="Additional preferences:
- Use GNU coreutils commands when available
- Prefer one-liners over scripts
- Always add the -v flag for verbose output"

# Example: Project-specific instructions
export ZSH_AI_PROMPT_EXTEND="This is a Rails project. Use bundle exec for all ruby commands."
```

The extension is added to the core prompt without replacing it, ensuring the AI still follows essential command generation rules.