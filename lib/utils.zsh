#!/usr/bin/env zsh

# Utility functions for zsh-ai

# Main query function that routes to the appropriate provider
_zsh_ai_query() {
    local query="$1"
    
    if [[ "$ZSH_AI_PROVIDER" == "ollama" ]]; then
        # Check if Ollama is running first
        if ! _zsh_ai_check_ollama; then
            echo "Error: Ollama is not running at $ZSH_AI_OLLAMA_URL"
            echo "Start Ollama with: ollama serve"
            return 1
        fi
        _zsh_ai_query_ollama "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "groq" ]]; then
        _zsh_ai_query_groq "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "anthropic" ]]; then
        _zsh_ai_query_anthropic "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "gemini" ]]; then
        _zsh_ai_query_gemini "$query"
    else
        echo "Error: Unsupported provider: $ZSH_AI_PROVIDER"
        return 1
    fi
}

# Optional: Add a helper function for users who prefer explicit commands
zsh-ai() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: zsh-ai \"your natural language command\""
        echo "Example: zsh-ai \"find all python files modified today\""
        echo ""
        echo "Current provider: $ZSH_AI_PROVIDER"
        if [[ "$ZSH_AI_PROVIDER" == "ollama" ]]; then
            echo "Ollama model: $ZSH_AI_OLLAMA_MODEL"
        fi
        return 1
    fi
    
    local query="$*"
    local cmd=$(_zsh_ai_query "$query")
    
    if [[ -n "$cmd" ]] && [[ "$cmd" != "Error:"* ]] && [[ "$cmd" != "API Error:"* ]]; then
        echo "$cmd"
        echo -n "Execute? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            eval "$cmd"
        fi
    else
        print -P "%F{red}Failed to generate command%f"
        if [[ -n "$cmd" ]]; then
            echo "$cmd"
        fi
        return 1
    fi
}