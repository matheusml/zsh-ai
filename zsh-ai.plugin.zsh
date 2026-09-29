#!/usr/bin/env zsh

# zsh-ai - AI-powered command suggestions for zsh
# Supports both hosted providers: OpenAI GPT, Anthropic Claude, Google Gemini, etc. and local providers: Ollama and Apfel```

# Get the directory where this plugin is installed
local plugin_dir="${0:A:h}"

# Source all the module files
source "${plugin_dir}/lib/config.zsh"
source "${plugin_dir}/lib/context.zsh"
source "${plugin_dir}/lib/providers/anthropic.zsh"
source "${plugin_dir}/lib/providers/ollama.zsh"
source "${plugin_dir}/lib/providers/apfel.zsh"
source "${plugin_dir}/lib/providers/gemini.zsh"
source "${plugin_dir}/lib/providers/openai.zsh"
source "${plugin_dir}/lib/providers/qwen.zsh"
source "${plugin_dir}/lib/providers/grok.zsh"
source "${plugin_dir}/lib/providers/mistral.zsh"
source "${plugin_dir}/lib/utils.zsh"
source "${plugin_dir}/lib/widget.zsh"

# Initialize the plugin
if _zsh_ai_validate_config; then
    _zsh_ai_init_widget
fi
