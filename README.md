# zsh-ai

> Ask your shell for the command you meant to write.

<img src="https://img.shields.io/github/v/release/matheusml/zsh-ai?label=version&color=yellow" alt="Version"> <img src="https://img.shields.io/badge/runtime-zsh-blue" alt="zsh runtime"> <img src="https://img.shields.io/badge/jq-optional-lightgrey" alt="jq optional"> <img src="https://img.shields.io/github/license/matheusml/zsh-ai?color=lightgrey" alt="License">

The hard part of the terminal usually is not knowing what to do. It is remembering the exact flags, quoting, and pipeline shape.

`zsh-ai` turns a zsh comment into a command. Type `#`, describe the job, press Enter, and the generated command appears in your prompt.

```bash
$ # find files larger than 100mb changed this week
$ find . -type f -size +100M -mtime -7
```

It does not run the command for you. You read it first, edit it if needed, then press Enter again.

## Why This Is Different

Most command help breaks your flow: search result, forum thread, copied snippet, little edits, fingers crossed.

`zsh-ai` stays on the command line. It sends useful context with your request, including project type, nearby files, git state, and OS. That means "run tests" can become the right command for the directory you are already in.

It is also small by design: zsh plus `curl` and `perl`, no Node runtime, no Python runtime. `jq` is optional.

## Install

```bash
brew tap matheusml/zsh-ai
brew install zsh-ai
```

Add this to `~/.zshrc`, with the API key above the `source` line:

```bash
export ANTHROPIC_API_KEY="your-key-here"
source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh
```

Keep API keys out of public dotfiles.

Reload your shell:

```bash
source ~/.zshrc
```

Then try:

```bash
# summarize disk usage for this folder
```

Prefer a local model on your machine?

```bash
ollama pull llama3.2
export ZSH_AI_PROVIDER="ollama"
```

Put the Ollama provider line above the `zsh-ai` source line.

Full setup lives in [INSTALL.md](INSTALL.md).

## Usage

### Comment Syntax

Type `#`, describe the job, then press Enter.

<img src="https://github.com/user-attachments/assets/eff46629-855c-41eb-9de3-a53040bd2654" alt="zsh-ai comment syntax demo" width="520">

```bash
$ # show what is using port 3000
$ lsof -i :3000

$ # show commits on this branch that are not on main
$ git log main..HEAD --oneline
```

### Direct Command

```bash
$ zsh-ai "find large files modified this week"
$ find . -type f -size +50M -mtime -7
```

The command is pushed into your prompt with `print -z`, ready to edit or run.

## Configuration

Switch providers with `ZSH_AI_PROVIDER`:

```bash
export ZSH_AI_PROVIDER="openai"
export OPENAI_API_KEY="your-key-here"
```

Add command preferences without replacing the built-in quoting rules:

```bash
export ZSH_AI_PROMPT_EXTEND="Prefer rg over grep, fd over find, and bat over cat."
```

## Docs

- [Installation](INSTALL.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md)
