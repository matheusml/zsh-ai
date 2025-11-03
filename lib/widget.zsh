#!/usr/bin/env zsh

# ZLE widget and key binding for zsh-ai

# Custom widget to intercept Enter key
_zsh_ai_accept_line() {
    # Check if the line starts with "# " and handle multiline input
    if [[ "$BUFFER" =~ ^'# ' ]]; then
        # Check if buffer contains newlines (multiline command)
        if [[ "$BUFFER" == *$'\n'* ]]; then
            # Multiline command detected - execute normally without AI processing
            zle .accept-line
            return
        fi
        
        # Extract the query (remove the "# " prefix)
        local query="${BUFFER:2}"
        
        # Add a loading indicator with animation
        local saved_buffer="$BUFFER"
        
        # Animation frames - rotating dots
        local dots=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        
        local frame=0
        
        # Create a temp file for the response
        local tmpfile=$(mktemp)
        
        # Disable job control notifications
        setopt local_options no_monitor no_notify
        
        # Start the API query in background using the shared function
        # Only redirect stdout to tmpfile, let stderr go to /dev/null to avoid mixing error output
        (_zsh_ai_execute_command "$query" > "$tmpfile" 2>/dev/null) &
        local pid=$!
        
        # Animate while waiting
        while kill -0 $pid 2>/dev/null; do
            BUFFER="$saved_buffer ${dots[$((frame % ${#dots[@]}))]}"
            zle redisplay
            ((frame++))
            # Use zsh's built-in sleep equivalent
            zle -R && sleep 0.1
        done
        
        # Get the response
        local cmd=$(cat "$tmpfile")
        local exit_code=$?
        rm -f "$tmpfile"
        
        if [[ -n "$cmd" ]] && [[ "$cmd" != "Error:"* ]] && [[ "$cmd" != "API Error:"* ]]; then
            # Simply replace the buffer with the generated command
            BUFFER="$cmd"

            # Move cursor to end of line
            CURSOR=$#BUFFER
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

# Create the widget and bind it
_zsh_ai_init_widget() {
    zle -N accept-line _zsh_ai_accept_line
}
