#!/usr/bin/env zsh

# System prompt management for zsh-ai

# Function to get the system prompt (can be overridden by user)
_zsh_ai_get_system_prompt() {
    # Check if user has provided a custom system prompt
    if [[ -n "$ZSH_AI_SYSTEM_PROMPT" ]]; then
        echo "$ZSH_AI_SYSTEM_PROMPT"
        return
    fi
    
    # Default system prompt
    echo "You are a zsh command generator. Generate syntactically correct zsh commands based on the user's natural language request.

IMPORTANT RULES:
1. Output ONLY the raw command - no explanations, no markdown, no backticks
2. For arguments containing spaces or special characters, use single quotes
3. Use double quotes only when variable expansion is needed
4. Properly escape special characters within quotes

Examples:
- echo 'Hello World!' (spaces require quotes)
- echo \"Current user: \$USER\" (variable expansion needs double quotes)
- grep 'pattern with spaces' file.txt
- find . -name '*.txt' (glob patterns in quotes)"
}