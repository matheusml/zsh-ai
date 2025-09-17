#!/usr/bin/env zsh

# Google Gemini API provider for zsh-ai

# Function to call Gemini API
_zsh_ai_query_gemini() {
    local query="$1"
    local response
    
    # Build context
    local context=$(_zsh_ai_build_context)
    local escaped_context=$(_zsh_ai_escape_json "$context")
    
    # Get system prompt and escape it
    local system_prompt=$(_zsh_ai_get_system_prompt)
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")
    
    # Prepare the JSON payload - escape quotes in the query
    local escaped_query=$(_zsh_ai_escape_json "$query")
    local json_payload=$(cat <<EOF
{
    "contents": [
        {
            "role": "user",
            "parts": [
                {
                    "text": "$escaped_query"
                }
            ]
        }
    ],
    "systemInstruction": {
        "parts": [
            {
                "text": "$escaped_system_prompt\n\nContext:\n$escaped_context"
            }
        ]
    },
    "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 256,
        "thinkingConfig": {
            "thinkingBudget": 0
        }
    }
}
EOF
)
    
    # Call the API
    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${ZSH_AI_GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        --header "content-type: application/json" \
        --data "$json_payload" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to connect to Gemini API"
        return 1
    fi
    
    # Debug: Uncomment to see raw response
    # echo "DEBUG: Raw response: $response" >&2
    
    # Extract the content from the response
    # Try using jq if available, otherwise fall back to sed/grep
    if command -v jq &> /dev/null; then
        local result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        if [[ -z "$result" ]]; then
            # Check for error message
            local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$error" ]]; then
                echo "API Error: $error"
            else
                echo "Error: Unable to parse response"
            fi
            return 1
        fi
        # Clean up the response - remove newlines and trailing whitespace
        # Commands should be single-line for shell execution
        result=$(echo "$result" | tr -d '\n' | sed 's/[[:space:]]*$//')
        echo "$result"
    else
        # Fallback parsing without jq - handle responses with newlines
        # Use sed to extract the text field, handling potential newlines
        local result=$(echo "$response" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p' | head -1)
        
        # If the simple extraction failed, try a more complex approach for multiline responses
        if [[ -z "$result" ]]; then
            # Extract text field even if it contains escaped newlines
            result=$(echo "$response" | perl -0777 -ne 'print $1 if /"text":"((?:[^"\\]|\\.)*)"/s' 2>/dev/null)
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