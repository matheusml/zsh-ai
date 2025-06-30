# 🪄 zsh-ai

> The lightweight AI assistant that lives in your terminal

Transform natural language into shell commands instantly. Works with both cloud-based AI (Anthropic Claude)
and local models (Ollama). No dependencies, no complex setup - just type what you want and get the command you
need.

<img src="https://img.shields.io/badge/dependencies-zero-brightgreen" alt="Zero Dependencies">
<img src="https://img.shields.io/badge/size-<5KB-blue" alt="Tiny Size">
<img src="https://img.shields.io/badge/setup-30_seconds-orange" alt="Quick Setup">

## Why zsh-ai?

**🪶 Featherweight** - A single 5KB shell script. No Python, no Node.js, etc.

**🚀 Lightning Fast** - Starts instantly with your shell.

**🎯 Dead Simple** - Just type `# what you want to do` and press Enter. That's it.

**🔒 Privacy First** - Use local Ollama models for complete privacy, or bring your own API keys. Your commands
stay local, API calls only when you trigger them.

**🛠️ Zero Dependencies** - Optionally `jq` for reliability.

**🧠 Context Aware** - Automatically detects project type, git status, and current directory for smarter
suggestions.

## Demo

https://github.com/user-attachments/assets/2d20b4ee-fe1a-466a-af9f-bb04b2bc4f71

```bash
$ # find all large files modified this week
$ find . -type f -size +50M -mtime -7

$ # kill process using port 3000
$ lsof -ti:3000 | xargs kill -9

$ # compress images in current directory
$ for img in *.{jpg,png}; do convert "$img" -quality 85 "$img"; done
```

Just type what you want in plain English, get the exact command you need.

## Prerequisites

- ✅ zsh 5.0+ (you probably already have this)
- ✅ `curl` (already on macOS/Linux)
- ➕ `jq` (optional, for better reliability)

**Choose your AI provider:**

- **Anthropic Claude** (default): [Get API key](https://console.anthropic.com/account/keys)
- **Ollama** (local): [Install Ollama](https://ollama.ai/download)

## Installation

### Homebrew (Recommended)

```bash
brew tap matheusml/zsh-ai
brew install zsh-ai
```

Add this to your `~/.zshrc`

```bash
source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh
```

### Oh My Zsh

```bash
git clone https://github.com/matheusml/zsh-ai ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-ai
```

Add `zsh-ai` to your plugins list in `~/.zshrc`:

```bash
plugins=(... zsh-ai)
```

### Manual Installation

```bash
git clone https://github.com/matheusml/zsh-ai ~/.zsh-ai
echo "source ~/.zsh-ai/zsh-ai.plugin.zsh" >> ~/.zshrc
```

### Setup

**Option 1: [Anthropic Claude](https://console.anthropic.com/account/keys) (default)**

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

**Option 2: [Ollama](https://ollama.ai/download) (local models)**

```bash
# Run a model (e.g., 3.2)
ollama run llama3.2

# Configure zsh-ai to use Ollama
export ZSH_AI_PROVIDER="ollama"
```

**Option 3: [Groq](https://console.groq.com/keys)**

```bash
export GROQ_API_KEY="your-api-key-here"
```

Add to your `~/.zshrc` to make it permanent.

### Configuration

All configuration is done via environment variables with sensible defaults:

```bash
# Choose AI provider: "anthropic" (default) or "ollama"
export ZSH_AI_PROVIDER="anthropic"

# Ollama-specific settings
export ZSH_AI_OLLAMA_MODEL="llama3.2"  # (default)
export ZSH_AI_OLLAMA_URL="http://localhost:11434"  # (default)
```

**That's it!** Most users won't need to change anything.

## Troubleshooting

### API Key not found

```bash
zsh-ai: Warning: ANTHROPIC_API_KEY not set. Plugin will not function.
```

Solution: Either set your API key or switch to Ollama:

```bash
# Option 1: Set Anthropic API key
export ANTHROPIC_API_KEY="your-key"

# Option 2: Use Ollama instead
export ZSH_AI_PROVIDER="ollama"
```

### Ollama not running

```bash
Error: Ollama is not running at http://localhost:11434
```

Solution: Start Ollama with `ollama serve`

### JSON parsing errors

Install `jq` for better reliability:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

## License

MIT - See LICENSE file for details

## Contributing

Pull requests welcome! Please open an issue first to discuss major changes.

## Security

- Your API key is never stored by the plugin
- Commands are generated locally, not logged
- Always review generated commands before execution
