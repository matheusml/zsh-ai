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
        # The check prints its own user-facing error when Ollama is unreachable
        _zsh_ai_check_ollama || return 1
        _zsh_ai_query_ollama "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "gemini" ]]; then
        _zsh_ai_query_gemini "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "openai" ]]; then
        _zsh_ai_query_openai "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "qwen" ]]; then
        _zsh_ai_query_qwen "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "grok" ]]; then
        _zsh_ai_query_grok "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "mistral" ]]; then
        _zsh_ai_query_mistral "$query"
    elif [[ "$ZSH_AI_PROVIDER" == "custom" ]]; then
        _zsh_ai_query_custom "$query"
	else
        _zsh_ai_query_anthropic "$query"
    fi
}

# Start _zsh_ai_query as a background job so callers can animate while waiting.
# Publishes the job through globals (a function can't return two values):
# $_zsh_ai_async_pid to poll with kill -0, $_zsh_ai_async_tmpfile for the response.
# Callers must setopt no_monitor/no_notify/no_bg_nice with local_options in their
# own scope: set here, the options would expire when this function returns and
# job control notifications would come back while the caller is still waiting.
_zsh_ai_async_start() {
    local query="$1"

    # Create a temp file for the response
    typeset -g _zsh_ai_async_tmpfile=$(mktemp)

    # Only redirect stdout to tmpfile, let stderr go to /dev/null to avoid mixing error output
    # >| so the redirect works when the user has noclobber set (mktemp already created the file)
    (_zsh_ai_query "$query" >| "$_zsh_ai_async_tmpfile" 2>/dev/null) &
    typeset -g _zsh_ai_async_pid=$!
}

# Reap the job started by _zsh_ai_async_start and put its output in $REPLY.
# Returns 0 only when the output looks like a usable command (query exited
# zero, response non-empty and not an error message).
_zsh_ai_async_collect() {
    # Reap the background job so it doesn't linger in the job table
    wait $_zsh_ai_async_pid 2>/dev/null
    local exit_code=$?

    typeset -g REPLY
    REPLY=$(cat "$_zsh_ai_async_tmpfile")
    rm -f "$_zsh_ai_async_tmpfile"
    unset _zsh_ai_async_pid _zsh_ai_async_tmpfile

    [[ $exit_code -eq 0 ]] && [[ -n "$REPLY" ]] && [[ "$REPLY" != "Error:"* ]] && [[ "$REPLY" != "API Error:"* ]]
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
        elif [[ "$ZSH_AI_PROVIDER" == "qwen" ]]; then
            echo "Qwen model: $ZSH_AI_QWEN_MODEL"
        elif [[ "$ZSH_AI_PROVIDER" == "grok" ]]; then
            echo "Grok model: $ZSH_AI_GROK_MODEL"
        elif [[ "$ZSH_AI_PROVIDER" == "mistral" ]]; then
            echo "Mistral model: $ZSH_AI_MISTRAL_MODEL"
        fi
        return 1
    fi
    
    local query="$*"
    
    # Animation frames - rotating dots (same as widget)
    local dots=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame=0
    
    # Disable job control notifications (same as widget; must stay in this
    # scope so it covers the wait below, see _zsh_ai_async_start)
    setopt local_options no_monitor no_notify no_bg_nice

    # Start the API query in background
    _zsh_ai_async_start "$query"

    # Animate while waiting
    while kill -0 $_zsh_ai_async_pid 2>/dev/null; do
        echo -ne "\r${dots[$((frame % ${#dots[@]}))]} "
        ((frame++))
        sleep 0.1
    done

    # Clear the line
    echo -ne "\r\033[K"

    if _zsh_ai_async_collect; then
        # Put the command in the ZLE buffer (same as # method)
        print -z "$REPLY"
    else
        # Show error with better visibility
        echo ""  # Blank line for spacing
        print -P "%F{red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%f"
        print -P "%F{red}❌ Failed to generate command%f"
        if [[ -n "$REPLY" ]]; then
            print -P "%F{red}$REPLY%f"
        fi
        print -P "%F{red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%f"
        echo ""  # Blank line for spacing
        return 1
    fi
}
