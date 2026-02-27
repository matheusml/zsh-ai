#!/usr/bin/env zsh

# Claude Code CLI provider for zsh-ai

# Function to check if Claude Code CLI is installed
_zsh_ai_check_claude_code() {
    command -v claude &> /dev/null
    return $?
}

# Function to query via Claude Code CLI
_zsh_ai_query_claude_code() {
    local query="$1"
    local response

    # Build context
    local context=$(_zsh_ai_build_context)
    local system_prompt=$(_zsh_ai_get_system_prompt "$context")

    # Build command arguments
    local -a cmd_args
    cmd_args=(claude -p "$query" --system-prompt "$system_prompt" --output-format text --max-turns 1)

    # Add model override if configured
    if [[ -n "$ZSH_AI_CLAUDE_CODE_MODEL" ]]; then
        cmd_args+=(--model "$ZSH_AI_CLAUDE_CODE_MODEL")
    fi

    # Call claude CLI
    response=$("${cmd_args[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        if [[ -n "$response" ]]; then
            echo "Error: claude CLI failed: $response"
        else
            echo "Error: Failed to run claude CLI (exit code $exit_code)"
        fi
        return 1
    fi

    if [[ -z "$response" ]]; then
        echo "Error: Empty response from claude CLI"
        return 1
    fi

    # Clean up the response - remove markdown code fences, newlines, and trailing whitespace
    local result
    result=$(printf "%s" "$response" | sed 's/^```[a-z]*$//' | tr -d '\n' | sed 's/[[:space:]]*$//')
    printf "%s" "$result"
}
