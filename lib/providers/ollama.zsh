#!/usr/bin/env zsh

# Ollama API provider for zsh-ai

# Function to check if Ollama is running
_zsh_ai_check_ollama() {
    curl -s "${ZSH_AI_OLLAMA_URL}/api/tags" >/dev/null 2>&1
    return $?
}

# Function to call Ollama API
_zsh_ai_query_ollama() {
    local query="$1"
    local response
    
    # Build context
    local context=$(_zsh_ai_build_context)
    local escaped_context=$(_zsh_ai_escape_json "$context")
    local system_prompt=$(_zsh_ai_get_system_prompt "$escaped_context")
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")
    
    # Prepare the JSON payload
    local escaped_query=$(_zsh_ai_escape_json "$query")
    local json_payload=$(cat <<EOF
{
    "model": "$ZSH_AI_OLLAMA_MODEL",
    "prompt": "$escaped_query",
    "system": "$escaped_system_prompt",
    "stream": false,
    "think": false,
    "options": {
        "temperature": 0.3
    }
}
EOF
)
    
    # Call the API
    response=$(curl -s "${ZSH_AI_OLLAMA_URL}/api/generate" \
        --header "content-type: application/json" \
        --data "$json_payload")
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to connect to Ollama. Is it running?"
        return 1
    fi
    
    # Extract the response
    if command -v jq &> /dev/null; then
        local result=$(echo "$response" | jq -r '.response // empty' 2>/dev/null)
        if [[ -z "$result" ]]; then
            # Check for error message
            local error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)
            if [[ -n "$error" ]]; then
                echo "Ollama Error: $error"
            else
                echo "Error: Unable to parse Ollama response"
            fi
            return 1
        fi
        # Clean up the response - remove newlines and trailing whitespace
        # Commands should be single-line for shell execution
        result=$(echo "$result" | tr -d '\n' | sed 's/[[:space:]]*$//')
        echo "$result"
    else
        # Fallback parsing without jq - handle responses with newlines
        # Use sed to extract the response field, handling potential newlines
        local result=$(echo "$response" | sed -n 's/.*"response":"\([^"]*\)".*/\1/p' | head -1)
        
        # If the simple extraction failed, try a more complex approach for multiline responses
        if [[ -z "$result" ]]; then
            # Extract response field even if it contains escaped newlines
            result=$(echo "$response" | perl -0777 -ne 'print $1 if /"response":"((?:[^"\\]|\\.)*)"/s' 2>/dev/null)
        fi
        
        if [[ -z "$result" ]]; then
            echo "Error: Unable to parse response (install jq for better reliability)"
            return 1
        fi
        
        # Unescape JSON string (handle \n, \t, etc.) and clean up
        result=$(echo "$result" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\r/\r/g; s/\\"/"/g; s/\\\\/\\/g')
        # Remove trailing newlines and spaces
        result=$(echo "$result" | sed 's/[[:space:]]*$//')
        echo "$result"
    fi
}