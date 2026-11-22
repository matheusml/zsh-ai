#!/usr/bin/env zsh

# ZLE widget and key binding for zsh-ai

# Custom widget to intercept Enter key
_zsh_ai_accept_line() {
    _zsh_ai_history_reset

    # Check if the line is an AI prompt and handle multiline input
    local query
    if query=$(_zsh_ai_prompt_query); then
        # Check if buffer contains newlines (multiline command)
        if [[ "$BUFFER" == *$'\n'* ]]; then
            # Multiline command detected - execute normally without AI processing
            zle .accept-line
            return
        fi

        
        # Add a loading indicator with animation
        local saved_buffer="$BUFFER"
        
        # Animation frames - rotating dots
        local dots=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        
        local frame=0
        
        # Create a temp file for the response
        local tmpfile=$(mktemp)
        
        # Disable job control notifications
        setopt local_options no_monitor no_notify no_bg_nice
        
        # Start the API query in background using the shared function
        # Only redirect stdout to tmpfile, let stderr go to /dev/null to avoid mixing error output
        # >| so the redirect works when the user has noclobber set (mktemp already created the file)
        (_zsh_ai_query "$query" >| "$tmpfile" 2>/dev/null) &
        local pid=$!
        
        # Animate while waiting
        while kill -0 $pid 2>/dev/null; do
            BUFFER="$saved_buffer ${dots[$((frame % ${#dots[@]}))]}"
            zle redisplay
            ((frame++))
            # Use zsh's built-in sleep equivalent
            zle -R && sleep 0.1
        done
        
        # Reap the background job so it doesn't linger in the job table
        wait $pid 2>/dev/null
        local exit_code=$?

        # Get the response
        local cmd=$(cat "$tmpfile")
        rm -f "$tmpfile"
        
        if [[ $exit_code -eq 0 ]] && [[ -n "$cmd" ]] && [[ "$cmd" != "Error:"* ]] && [[ "$cmd" != "API Error:"* ]]; then
            # Simply replace the buffer with the generated command
            BUFFER="$cmd"

            # Move cursor to end of line
            CURSOR=$#BUFFER

            _zsh_ai_history_save "$query"
            _zsh_ai_history_reset
        else
            # Show error - keep it visible
            echo ""  # New line for better visibility
            print -P "%F{red}❌ Failed to generate command%f"
            if [[ -n "$cmd" ]]; then
                print -P "%F{red}$cmd%f"
            fi
            echo ""  # Extra line for readability

            # Restore original buffer so user can see what query failed
            BUFFER="$saved_buffer"
            CURSOR=$#BUFFER

            # Sleep briefly to ensure error is visible before prompt redraws
            sleep 0.5
        fi

        # Redraw the prompt
        zle reset-prompt
    else
        # Normal command - execute as usual
        zle .accept-line
    fi
}

# Up/down arrows browse saved prompts while the buffer is a zsh-ai prompt; otherwise the normal shell history runs
_zsh_ai_history_up() {
    _zsh_ai_history_step -1 || zle .up-line-or-history
}

_zsh_ai_history_down() {
    _zsh_ai_history_step 1 || zle .down-line-or-history
}

# Create the widget and bind it
# Uses precmd hook to defer registration until ZLE is fully initialized
# This fixes the issue where zle -N fails silently during plugin sourcing
_zsh_ai_init_widget() {
    # Respect the toggle: when disabled, never intercept accept-line so the
    # inline trigger (default "# ") behaves like a normal shell comment.
    _zsh_ai_comment_hook_enabled || return

    _zsh_ai_do_init() {
        zle -N accept-line _zsh_ai_accept_line
        zle -N zsh-ai-history-up _zsh_ai_history_up
        zle -N zsh-ai-history-down _zsh_ai_history_down
        bindkey '^[[A' zsh-ai-history-up
        bindkey '^[OA' zsh-ai-history-up
        bindkey '^[[B' zsh-ai-history-down
        bindkey '^[OB' zsh-ai-history-down
        add-zsh-hook -d precmd _zsh_ai_do_init
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _zsh_ai_do_init
}
