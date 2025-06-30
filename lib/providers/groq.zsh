#!/usr/bin/env zsh

# Groq API provider for zsh-ai

# Function to call Groq API
_zsh_ai_query_groq() {
    local query="$1"
    local response
    
    # Build context
    local context=$(_zsh_ai_build_context)
    local escaped_context="${context//\"/\\\"}"
    escaped_context="${escaped_context//$'\n'/\\n}"
    
    # Check for custom model or use default
    local model="${GROQ_MODEL:-llama-3.3-70b-versatile}"
    
    # Prepare the JSON payload - escape quotes in the query
    local escaped_query="${query//\"/\\\"}"
    local json_payload=$(cat <<EOF
{
    "model": "$model",
    "max_tokens": 256,
    "messages": [
        {
            "role": "system",
            "content": "You are a helpful assistant that generates shell commands. When given a natural language description, respond ONLY with the appropriate shell command. Do not include any explanation, markdown formatting, or backticks. Just the raw command.\n\nContext:\n$escaped_context"
        },
        {
            "role": "user",
            "content": "$escaped_query"
        }
    ]
}
EOF
)
    
    response=$(curl -s https://api.groq.com/openai/v1/chat/completions \
        --header "Authorization: Bearer $GROQ_API_KEY" \
        --header "content-type: application/json" \
        --data "$json_payload" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to connect to Groq API"
        return 1
    fi
    
    # Debug: Uncomment to see raw response
    # echo "DEBUG: Raw response: $response" >&2
    
    # echo "$response" | jq -r '.choices[0].message.content'
    
    # Extract the content from the response
    # Try using jq if available, otherwise fall back to sed/grep
    if command -v jq &> /dev/null; then
        local result=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
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
        echo "$result"
    else
        # Fallback parsing without jq
        local result=$(echo "$response" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"\([^"]*\)"/\1/')
        if [[ -z "$result" ]]; then
            echo "Error: Unable to parse response (install jq for better reliability)"
            return 1
        fi
        echo "$result"
    fi
}