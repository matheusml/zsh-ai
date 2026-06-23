#!/usr/bin/env zsh

# OpenAI Codex response generation for zsh-ai

_ZSH_AI_CODEX_PARSER_FILE="${${(%):-%x}:A:h}/parse_response.pl"

_zsh_ai_codex_parse_response() {
    local response="$1"

    printf "%s" "$response" | perl "$_ZSH_AI_CODEX_PARSER_FILE" 2>/dev/null
}

_zsh_ai_query_openai_codex_once() {
    local json_payload="$1"
    local response
    local body
    local http_status
    local account_header=()

    [[ -n "$_ZSH_AI_CODEX_ACCOUNT_ID" ]] && account_header=(--header "ChatGPT-Account-ID: $_ZSH_AI_CODEX_ACCOUNT_ID")

    response=$(curl -s -w $'\n%{http_code}' "${ZSH_AI_CODEX_URL}" \
        --header "Authorization: Bearer $_ZSH_AI_CODEX_ACCESS_TOKEN" \
        "${account_header[@]}" \
        --header "content-type: application/json" \
        --header "accept: text/event-stream" \
        --header "User-Agent: zsh-ai" \
        --header "originator: zsh-ai" \
        --data "$json_payload" 2>&1)
    local curl_status=$?

    if [[ $curl_status -ne 0 ]]; then
        echo "Error: Failed to connect to Codex API"
        return 1
    fi

    http_status="${response##*$'\n'}"
    body="${response%$'\n'*}"
    if [[ ! "$http_status" == <-> ]]; then
        http_status=200
        body="$response"
    fi

    typeset -g _ZSH_AI_CODEX_LAST_STATUS="$http_status"
    typeset -g _ZSH_AI_CODEX_LAST_BODY="$body"
}

_zsh_ai_query_openai_codex() {
    local query="$1"
    local response
    local result

    # Build context
    local context=$(_zsh_ai_build_context)
    local escaped_context=$(_zsh_ai_escape_json "$context")
    local system_prompt=$(_zsh_ai_get_system_prompt "$escaped_context")
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")

    # Prepare the JSON payload - escape quotes in the query
    local escaped_query=$(_zsh_ai_escape_json "$query")

    # Refresh the auth token if required
    _zsh_ai_codex_refresh_if_needed || return 1

    local json_payload=$(
        cat <<EOF
{
    "model": "${ZSH_AI_CODEX_MODEL}",
    "instructions": "$escaped_system_prompt",
    "input": [
        {
            "role": "user",
            "content": [
                {
                    "type": "input_text",
                    "text": "$escaped_query"
                }
            ]
        }
    ],
    "store": false,
    "stream": true
}
EOF
    )

    _zsh_ai_query_openai_codex_once "$json_payload" || return 1
    response="$_ZSH_AI_CODEX_LAST_BODY"
    if [[ "$_ZSH_AI_CODEX_LAST_STATUS" == "401" ]]; then
        # Treat one 401 as recoverable auth drift: refresh credentials once and
        # retry, but avoid loops if refreshed credentials are also rejected.
        _zsh_ai_codex_refresh || return 1
        _zsh_ai_query_openai_codex_once "$json_payload" || return 1
        response="$_ZSH_AI_CODEX_LAST_BODY"
    fi

    if [[ "$_ZSH_AI_CODEX_LAST_STATUS" -lt 200 || "$_ZSH_AI_CODEX_LAST_STATUS" -ge 300 ]]; then
        # After the special 401 remediation, surface any remaining non-2xx
        # response as an API failure, preserving backend error text when possible.
        result=$(_zsh_ai_codex_parse_response "$response")
        if [[ -n "$result" && "$result" == API\ Error:* ]]; then
            echo "$result"
        else
            echo "API Error: Codex request failed with HTTP $_ZSH_AI_CODEX_LAST_STATUS"
        fi
        return 1
    fi

    result=$(_zsh_ai_codex_parse_response "$response")
    local parse_status=$?
    printf "%s" "$result"
    return $parse_status
}
