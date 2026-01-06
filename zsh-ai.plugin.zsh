#!/usr/bin/env zsh

# zsh-ai - AI-powered command suggestions for zsh
# Supports Anthropic Claude, Google Gemini, OpenAI, Mistral AI, and local Ollama models

# Get the directory where this plugin is installed
local plugin_dir="${0:A:h}"

# Source all the module files
source "${plugin_dir}/lib/config.zsh"
source "${plugin_dir}/lib/context.zsh"
source "${plugin_dir}/lib/providers/anthropic.zsh"
source "${plugin_dir}/lib/providers/ollama.zsh"
source "${plugin_dir}/lib/providers/gemini.zsh"
source "${plugin_dir}/lib/providers/openai.zsh"
source "${plugin_dir}/lib/providers/grok.zsh"
source "${plugin_dir}/lib/providers/mistral.zsh"
source "${plugin_dir}/lib/utils.zsh"
source "${plugin_dir}/lib/widget.zsh"

# Initialize the plugin
if _zsh_ai_validate_config; then
    _zsh_ai_init_widget
fi