# 🪄 zsh-ai

> The lightweight AI assistant that lives in your terminal

Transform natural language into shell commands instantly. Works with cloud-based AI (Anthropic Claude, Google Gemini, OpenAI, Grok, Mistral) and local models (Ollama). No dependencies, no complex setup - just type what you want and get the command you need.

<img src="https://img.shields.io/github/v/release/matheusml/zsh-ai?label=version&color=yellow" alt="Version"> <img src="https://img.shields.io/badge/dependencies-zero-brightgreen" alt="Zero Dependencies"> <img src="https://img.shields.io/badge/size-<5KB-blue" alt="Tiny Size"> <img src="https://img.shields.io/github/license/matheusml/zsh-ai?color=lightgrey" alt="License">

## Why zsh-ai?

**🪶 Featherweight** - A single 5KB shell script. No Python, no Node.js, etc.

**🚀 Lightning Fast** - Starts instantly with your shell.

**🎯 Dead Simple** - Just type `# what you want to do` and press Enter. That's it.

**🔒 Privacy First** - Use local Ollama models for complete privacy, or bring your own API keys. Your commands stay local, API calls only when you trigger them.

**🛠️ Zero Dependencies** - Optionally `jq` for reliability.

**🧠 Context Aware** - Automatically detects project type, git status, and current directory for smarter suggestions.

## Demo

### Method 1: Comment Syntax (Recommended)
Type `#` followed by what you want to do, then press Enter. It's that simple!

<img src="https://github.com/user-attachments/assets/eff46629-855c-41eb-9de3-a53040bd2654" alt="Method 1 Demo" width="480">


```bash
$ # find all large files modified this week
$ find . -type f -size +50M -mtime -7

$ # kill process using port 3000  
$ lsof -ti:3000 | xargs kill -9

$ # compress images in current directory
$ for img in *.{jpg,png}; do convert "$img" -quality 85 "$img"; done
```

---

### Method 2: Direct Command
Prefer explicit commands? Use `zsh-ai` followed by your natural language request.

<img src="https://github.com/user-attachments/assets/e58f0b99-68bf-45a5-87b9-ba7f925ddc87" alt="Method 2 Demo" width="480">


```bash
$ zsh-ai "find all large files modified this week"
$ find . -type f -size +50M -mtime -7

$ zsh-ai "kill process using port 3000"
$ lsof -ti:3000 | xargs kill -9

$ zsh-ai "compress images in current directory"
$ for img in *.{jpg,png}; do convert "$img" -quality 85 "$img"; done
```

## Quick Start

1. **Install** - Choose your preferred method:
   ```bash
   # Homebrew (recommended)
   brew tap matheusml/zsh-ai && brew install zsh-ai
   ```
   
2. **Configure** - Set up your AI provider (Anthropic, Gemini, OpenAI, Mistral, or Ollama)

3. **Use** - Type `# your command` and press Enter!

📚 **[Full Installation Guide →](INSTALL.md)**

## Documentation

- 📦 **[Installation & Setup](INSTALL.md)** - Detailed installation instructions for all package managers
- 🔧 **[Configuration](INSTALL.md#configuration)** - API keys, providers, and customization options  
- 🚨 **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
- 🤝 **[Contributing](CONTRIBUTING.md)** - Help make zsh-ai better!
