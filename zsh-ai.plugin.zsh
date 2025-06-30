#!/usr/bin/env zsh

# zsh-ai - AI-powered command suggestions for zsh
# Supports both Anthropic Claude, Groq and local Ollama models

# Get the directory where this plugin is installed
local plugin_dir="${0:A:h}"

# Source all the module files
source "${plugin_dir}/lib/config.zsh"
source "${plugin_dir}/lib/context.zsh"

source "${plugin_dir}/lib/providers/anthropic.zsh"
source "${plugin_dir}/lib/providers/ollama.zsh"
source "${plugin_dir}/lib/providers/groq.zsh"

source "${plugin_dir}/lib/utils.zsh"
source "${plugin_dir}/lib/widget.zsh"

# Initialize the plugin
if _zsh_ai_validate_config; then
    _zsh_ai_init_widget
fi