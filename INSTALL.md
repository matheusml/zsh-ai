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
# Add additional instructions to the AI without replacing core functionality
export ZSH_AI_SYSTEM_PROMPT="Prefer using ripgrep (rg) over grep when searching"
```

**That's it!** Most users won't need to change anything.

### Advanced Configuration

#### Custom System Prompt Extensions

You can extend the system prompt with additional instructions while maintaining core functionality. Your custom instructions are appended to the default prompt, ensuring the AI always knows to output clean, executable commands.

This is useful for:
- Adding preferences for specific tools or commands
- Including context about your development environment  
- Setting project-specific rules or conventions

```bash
# Example: Prefer modern tools
export ZSH_AI_SYSTEM_PROMPT="Prefer ripgrep (rg) over grep, fd over find, and exa over ls"

# Example: Security-conscious development
export ZSH_AI_SYSTEM_PROMPT="Always use safe defaults. Avoid force flags like -f unless explicitly requested. Add --dry-run for destructive operations"

# Example: Node.js environment
export ZSH_AI_SYSTEM_PROMPT="When working with Node.js projects, prefer pnpm over npm. Use node: protocol for built-in modules"

# Example: Git workflow preferences  
export ZSH_AI_SYSTEM_PROMPT="For git commands, always use --verbose flag. Prefer descriptive branch names with prefixes like feature/, bugfix/, etc"
```

Note: Your custom instructions extend the base behavior - the AI will always output raw, executable commands first, then apply your additional preferences.