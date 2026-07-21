#!/usr/bin/env zsh

# ZLE widget and key binding for zsh-ai

# Custom widget to intercept Enter key
_zsh_ai_accept_line() {
    local trigger="${ZSH_AI_TRIGGER:-# }"

    # Check if the line starts with the configured trigger and handle multiline input
    if [[ "$BUFFER" == "$trigger"* ]]; then
        # Check if buffer contains newlines (multiline command)
        if [[ "$BUFFER" == *$'\n'* ]]; then
            # Multiline command detected - execute normally without AI processing
            zle .accept-line
            return
        fi

        # Extract the query (remove the trigger prefix)
        local query="${BUFFER#"$trigger"}"
        
        # Add a loading indicator with animation
        local saved_buffer="$BUFFER"
        
        # Animation frames - rotating dots
        local dots=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        
        local frame=0
        
        # Disable job control notifications (must stay in this scope so it
        # covers the wait below, see _zsh_ai_async_start)
        setopt local_options no_monitor no_notify no_bg_nice

        # Start the API query in background using the shared helper
        _zsh_ai_async_start "$query"

        # Animate while waiting
        while kill -0 $_zsh_ai_async_pid 2>/dev/null; do
            BUFFER="$saved_buffer ${dots[$((frame % ${#dots[@]}))]}"
            zle redisplay
            ((frame++))
            # Use zsh's built-in sleep equivalent
            zle -R && sleep 0.1
        done

        if _zsh_ai_async_collect; then
            # Simply replace the buffer with the generated command
            BUFFER="$REPLY"

            # Move cursor to end of line
            CURSOR=$#BUFFER
        else
            # Show error - keep it visible
            echo ""  # New line for better visibility
            print -P "%F{red}❌ Failed to generate command%f"
            if [[ -n "$REPLY" ]]; then
                print -P "%F{red}$REPLY%f"
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

# Create the widget and bind it
# Uses precmd hook to defer registration until ZLE is fully initialized
# This fixes the issue where zle -N fails silently during plugin sourcing
_zsh_ai_init_widget() {
    # Respect the toggle: when disabled, never intercept accept-line so the
    # inline trigger (default "# ") behaves like a normal shell comment.
    _zsh_ai_comment_hook_enabled || return

    _zsh_ai_do_init() {
        zle -N accept-line _zsh_ai_accept_line
        add-zsh-hook -d precmd _zsh_ai_do_init
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _zsh_ai_do_init
}
