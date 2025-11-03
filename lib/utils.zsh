#!/usr/bin/env zsh

# Utility functions for zsh-ai

# Function to get the standardized system prompt for all providers
_zsh_ai_get_system_prompt() {
    local context="$1"
    local base_prompt="You are a zsh command generator. Generate syntactically correct zsh commands based on the user's natural language request.\n\nIMPORTANT RULES:\n1. Output ONLY the raw command - no explanations, no markdown, no backticks\n2. For arguments containing spaces or special characters, use single quotes\n3. Use double quotes only when variable expansion is needed\n4. Properly escape special characters within quotes\n\nExamples:\n- echo 'Hello World!' (spaces require quotes)\n- echo \"Current user: \$USER\" (variable expansion needs double quotes)\n- grep 'pattern with spaces' file.txt\n- find . -name '*.txt' (glob patterns in quotes)"
    
    # Add custom prompt extension if provided
    if [[ -n "$ZSH_AI_PROMPT_EXTEND" ]]; then
        echo "${base_prompt}\n\n${ZSH_AI_PROMPT_EXTEND}\n\nContext:\n$context"
    else
        echo "${base_prompt}\n\nContext:\n$context"
    fi
}

# Function to properly escape strings for JSON
_zsh_ai_escape_json() {
    # Use printf and perl for reliable JSON escaping
    printf '%s' "$1" | perl -0777 -pe 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g; s/\x08/\\b/g; s/[\x00-\x07\x0B\x0E-\x1F]//g'
}

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
    elif [[ "$ZSH_AI_PROVIDER" == "gemini" ]]; then
        _zsh_ai_query_gemini "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "openai" ]]; then
        _zsh_ai_query_openai "$query"
    else
        _zsh_ai_query_anthropic "$query"
    fi
}

# Shared function to handle AI command execution
_zsh_ai_execute_command() {
    local query="$1"
    local cmd=$(_zsh_ai_query "$query")
    
    if [[ -n "$cmd" ]] && [[ "$cmd" != "Error:"* ]] && [[ "$cmd" != "API Error:"* ]]; then
        echo "$cmd"
        return 0
    else
        # Return error
        echo "$cmd"
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
        elif [[ "$ZSH_AI_PROVIDER" == "gemini" ]]; then
            echo "Gemini model: $ZSH_AI_GEMINI_MODEL"
        elif [[ "$ZSH_AI_PROVIDER" == "openai" ]]; then
            echo "OpenAI model: $ZSH_AI_OPENAI_MODEL"
        fi
        return 1
    fi
    
    local query="$*"
    
    # Animation frames - rotating dots (same as widget)
    local dots=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame=0
    
    # Create a temp file for the response
    local tmpfile=$(mktemp)
    
    # Disable job control notifications (same as widget)
    setopt local_options no_monitor no_notify
    
    # Start the API query in background
    (_zsh_ai_execute_command "$query" > "$tmpfile" 2>/dev/null) &
    local pid=$!
    
    # Animate while waiting
    while kill -0 $pid 2>/dev/null; do
        echo -ne "\r${dots[$((frame % ${#dots[@]}))]} "
        ((frame++))
        sleep 0.1
    done
    
    # Clear the line
    echo -ne "\r\033[K"
    
    # Get the response and exit code
    wait $pid
    local exit_code=$?
    local cmd=$(cat "$tmpfile")
    rm -f "$tmpfile"
    
    if [[ $exit_code -eq 0 ]] && [[ -n "$cmd" ]] && [[ "$cmd" != "Error:"* ]] && [[ "$cmd" != "API Error:"* ]]; then
        # Put the command in the ZLE buffer (same as # method)
        print -z "$cmd"
    else
        # Show error with better visibility
        echo ""  # Blank line for spacing
        print -P "%F{red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%f"
        print -P "%F{red}❌ Failed to generate command%f"
        if [[ -n "$cmd" ]]; then
            print -P "%F{red}$cmd%f"
        fi
        print -P "%F{red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%f"
        echo ""  # Blank line for spacing
        return 1
    fi
}
