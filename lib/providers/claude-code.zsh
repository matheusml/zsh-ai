#!/usr/bin/env zsh

# Claude Code CLI provider for zsh-ai
#
# Talks to the locally installed `claude` binary in print mode instead of an
# HTTP API, so it works with whatever credentials Claude Code already uses and
# needs no ANTHROPIC_API_KEY.

# Function to check the Claude Code CLI is installed, printing the user-facing
# error when it isn't
_zsh_ai_check_claude_code() {
    if command -v "$ZSH_AI_CLAUDE_CODE_BIN" &> /dev/null; then
        return 0
    fi
    echo "Error: Claude Code CLI '$ZSH_AI_CLAUDE_CODE_BIN' not found in PATH"
    echo "Install it from https://claude.com/claude-code, or set ZSH_AI_CLAUDE_CODE_BIN to its path"
    return 1
}

# Function to call the Claude Code CLI
_zsh_ai_query_claude_code() {
    local query="$1"
    local response

    # Build context - no JSON escaping needed, the prompt is passed as an argument
    local context=$(_zsh_ai_build_context)
    # Claude Code is conversational by default, so restate the single-line rule
    local system_prompt="$(_zsh_ai_get_system_prompt "$context")

Reply with the command only, on a single line. No preamble, no reasoning, no markdown code fences."

    local -a claude_args
    claude_args=(
        -p
        --system-prompt "$system_prompt"
        --input-format text
        --output-format text
        # No tools: this is a one-shot completion, nothing should run or prompt
        --tools ""
        --permission-prompts none
        --strict-mcp-config
        --disable-slash-commands
        --no-session-persistence
    )

    # Empty model means "whatever Claude Code is already configured to use"
    if [[ -n "$ZSH_AI_CLAUDE_CODE_MODEL" ]]; then
        claude_args+=(--model "$ZSH_AI_CLAUDE_CODE_MODEL")
    fi

    # Safe mode keeps CLAUDE.md, hooks, plugins and MCP servers out of the
    # request - without it the cwd's project instructions steer the suggestion
    if _zsh_ai_is_true "$ZSH_AI_CLAUDE_CODE_SAFE_MODE"; then
        claude_args+=(--safe-mode)
    fi

    # Split extra user args into shell words, then strip the quoting they used
    if [[ -n "$ZSH_AI_CLAUDE_CODE_ARGS" ]]; then
        claude_args+=(${(Q)${(z)ZSH_AI_CLAUDE_CODE_ARGS}})
    fi

    # Feed the query on stdin so a request starting with '-' isn't parsed as a flag.
    # stderr is dropped: Claude Code writes update notices and warnings there.
    response=$(printf '%s' "$query" | "$ZSH_AI_CLAUDE_CODE_BIN" "${claude_args[@]}" 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        # On failure Claude Code prints the reason (bad model, expired auth) on stdout
        if [[ -n "$response" ]]; then
            echo "Claude Code Error: $(printf "%s" "$response" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        else
            echo "Error: Claude Code CLI failed. Check 'claude auth' and try 'claude -p hello'"
        fi
        return 1
    fi

    if [[ -z "$response" ]]; then
        echo "Error: Empty response from Claude Code"
        return 1
    fi

    # Clean up the response - drop markdown code fences and blank lines, then
    # collapse to one line. Commands should be single-line for shell execution.
    local result=$(printf "%s" "$response" | sed '/^[[:space:]]*```/d; /^[[:space:]]*$/d' | tr -d '\n' | sed 's/[[:space:]]*$//')

    if [[ -z "$result" ]]; then
        echo "Error: Unable to parse Claude Code response"
        return 1
    fi

    printf "%s" "$result"
}
