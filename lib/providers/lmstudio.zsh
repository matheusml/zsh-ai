#!/usr/bin/env zsh

# LM Studio API provider for zsh-ai (OpenAI-compatible chat completions)

# Function to check if LM Studio's local server is reachable, printing the user-facing error when it isn't
_zsh_ai_check_lmstudio() {
    local models_url="${ZSH_AI_LMSTUDIO_URL%/*/*}/models"
    if curl -sf --max-time 5 "$models_url" >/dev/null 2>&1; then
        return 0
    fi
    echo "Error: LM Studio is not reachable at $models_url"
    echo "Load $ZSH_AI_LMSTUDIO_MODEL in LM Studio and start the local server (Developer tab, port 1234)."
    echo "If it's already running, ZSH_AI_LMSTUDIO_URL must be the full chat-completions URL (e.g. http://127.0.0.1:1234/v1/chat/completions)"
    return 1
}

# Drop reasoning blocks and code fences, then keep only the first command line
_zsh_ai_clean_lmstudio_response() {
    printf '%s' "$1" | perl -0777 -pe '
        s/\A.*?<\/think>//s;
        s/\s*<think>.*?<\/think>//gs;
        s/\s*<think>.*//s;
        s/\A\s+//;
        s/\AAssistant:\s*//;
        s/\A[-*]\s+//;
        s/\A```[^\n]*\n//;
        s/\n```[^\n]*\s*\z//s;
        s/\A([^\n]*)\n.*\z/$1/s;
        s/\s+\z//;
    '
}

# Function to call LM Studio's chat-completions API
_zsh_ai_query_lmstudio() {
    local query="$1"
    local response

    local context=$(_zsh_ai_build_context)
    local system_prompt=$(_zsh_ai_get_system_prompt "$context")
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")
    local escaped_query=$(_zsh_ai_escape_json "$query")

    local max_tokens="${ZSH_AI_LMSTUDIO_MAX_TOKENS:-256}"
    [[ "$max_tokens" == <1-> ]] || max_tokens=256

    local json_payload=$(cat <<EOF
{
    "model": "$ZSH_AI_LMSTUDIO_MODEL",
    "messages": [
        {"role": "system", "content": "$escaped_system_prompt"},
        {"role": "user", "content": "$escaped_query"}
    ],
    "max_tokens": ${max_tokens},
    "temperature": 0.3,
    "stream": false
}
EOF
)

    response=$(curl -s --max-time 120 "$ZSH_AI_LMSTUDIO_URL" \
        --header "content-type: application/json" \
        --data "$json_payload")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to connect to LM Studio at $ZSH_AI_LMSTUDIO_URL. Is the local server running?"
        return 1
    fi

    local result
    if command -v jq &> /dev/null; then
        result=$(printf "%s" "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
        if [[ -z "$result" ]]; then
            local error=$(printf "%s" "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$error" ]]; then
                echo "LM Studio Error: $error"
            else
                echo "Error: Unable to parse LM Studio response"
                [[ -n "$response" ]] && echo "Response: ${response:0:200}"
            fi
            return 1
        fi
    else
        local error=$(printf "%s" "$response" | perl -0777 -ne 'print $1 if /"error"\s*:\s*\{.*?"message"\s*:\s*"((?:[^"\\]|\\.)*)"/s' 2>/dev/null)
        if [[ -n "$error" ]]; then
            echo "LM Studio Error: $error"
            return 1
        fi
        result=$(printf "%s" "$response" | perl -0777 -ne 'print $1 if /"content"\s*:\s*"((?:[^"\\]|\\.)*)"/s' 2>/dev/null)
        if [[ -z "$result" ]]; then
            echo "Error: Unable to parse response (install jq for better reliability)"
            [[ -n "$response" ]] && echo "Response: ${response:0:200}"
            return 1
        fi
        result=$(printf "%s" "$result" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\r/\r/g; s/\\"/"/g; s/\\\\/\\/g')
    fi

    result=$(_zsh_ai_clean_lmstudio_response "$result")
    if [[ -z "$result" ]]; then
        echo "Error: LM Studio returned an empty command"
        return 1
    fi
    printf "%s" "$result"
}
