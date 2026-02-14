#!/usr/bin/env zsh

# Tests for OpenCode provider

source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/opencode.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

curl() {
    if [[ "$*" == *"opencode.ai/zen"* ]]; then
        cat <<EOF
{
    "choices": [
        {
            "message": {
                "content": "ls -la"
            }
        }
    ]
}
EOF
        return 0
    fi
    command curl "$@"
}

test_opencode_query_success() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"

    local result=$(_zsh_ai_query_opencode "list files")
    assert_equals "$result" "ls -la"
}

test_opencode_query_error_response() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"
    
    curl() {
        if [[ "$*" == *"opencode.ai/zen"* ]]; then
            cat <<EOF
{
    "error": {
        "message": "Invalid API key"
    }
}
EOF
            return 0
        fi
        command curl "$@"
    }
    
    local result=$(_zsh_ai_query_opencode "list files")
    assert_contains "$result" "API Error:"
}

test_opencode_json_escaping() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"
    
    local result=$(_zsh_ai_query_opencode "test \"quotes\" and \$variables")
    assert_not_empty "$result"
}

test_opencode_handles_response_with_newline() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"
    export ZSH_AI_OPENCODE_URL="https://opencode.ai/zen/v1/chat/completions"

    curl() {
        if [[ "$*" == *"opencode.ai/zen"* ]]; then
            cat <<EOF
{
    "choices": [
        {
            "message": {
                "content": "cd /home"
            }
        }
    ]
}
EOF
            return 0
        fi
        return 1
    }

    local result=$(_zsh_ai_query_opencode "go home")
    assert_equals "$result" "cd /home"
}

test_opencode_handles_response_without_jq() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"

    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    curl() {
        if [[ "$*" == *"opencode.ai/zen"* ]]; then
            echo '{"choices":[{"message":{"content":"echo test"}}]}'
            return 0
        fi
        builtin command curl "$@"
    }

    local result=$(_zsh_ai_query_opencode "echo test")
    assert_equals "$result" "echo test"
}

test_opencode_uses_default_url() {
    unset ZSH_AI_OPENCODE_URL
    source "${PLUGIN_DIR}/lib/config.zsh"
    assert_equals "$ZSH_AI_OPENCODE_URL" "https://opencode.ai/zen/v1/chat/completions"
}

test_opencode_uses_custom_url() {
    export ZSH_AI_OPENCODE_URL="https://custom.example.com/v1/chat/completions"
    assert_equals "$ZSH_AI_OPENCODE_URL" "https://custom.example.com/v1/chat/completions"
}

test_opencode_default_model() {
    unset ZSH_AI_OPENCODE_MODEL
    source "${PLUGIN_DIR}/lib/config.zsh"
    assert_equals "$ZSH_AI_OPENCODE_MODEL" "opencode/gpt-5-nano"
}

assert_not_empty() {
    [[ -n "$1" ]]
}

echo "Running OpenCode provider tests..."
test_opencode_query_success && echo "✓ OpenCode query success"
test_opencode_query_error_response && echo "✓ OpenCode error response handling"
test_opencode_json_escaping && echo "✓ OpenCode JSON escaping"
test_opencode_handles_response_with_newline && echo "✓ OpenCode handles response with trailing newline"
test_opencode_handles_response_without_jq && echo "✓ OpenCode handles response without jq"
test_opencode_uses_default_url && echo "✓ OpenCode uses default URL"
test_opencode_uses_custom_url && echo "✓ OpenCode uses custom URL"
test_opencode_default_model && echo "✓ OpenCode default model"

echo ""
echo "Running OpenCode validation tests..."

test_opencode_requires_api_key() {
    unset OPENCODE_API_KEY
    unset ZSH_AI_OPENCODE_API_KEY
    export ZSH_AI_PROVIDER="opencode"

    local result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "OPENCODE_API_KEY not set"
}

test_opencode_validates_with_api_key() {
    export OPENCODE_API_KEY="test-key"
    export ZSH_AI_PROVIDER="opencode"

    local result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "0"
}

test_opencode_validates_with_zsh_ai_key() {
    unset OPENCODE_API_KEY
    export ZSH_AI_OPENCODE_API_KEY="sk-custom-key"
    export ZSH_AI_PROVIDER="opencode"

    local result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "0"
}

test_opencode_key_takes_precedence() {
    export OPENCODE_API_KEY="original-key"
    export ZSH_AI_OPENCODE_API_KEY="override-key"
    export ZSH_AI_PROVIDER="opencode"
    export ZSH_AI_OPENCODE_MODEL="opencode/gpt-5-nano"
    export ZSH_AI_OPENCODE_URL="https://opencode.ai/zen/v1/chat/completions"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"opencode.ai/zen"* ]]; then
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_opencode "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    if [[ "$curl_args" != *"override-key"* ]]; then
        echo "FAIL: ZSH_AI_OPENCODE_API_KEY should take precedence"
        return 1
    fi
    if [[ "$curl_args" == *"original-key"* ]]; then
        echo "FAIL: OPENCODE_API_KEY should not be used when ZSH_AI_OPENCODE_API_KEY is set"
        return 1
    fi
    return 0
}

test_opencode_requires_api_key && echo "✓ OpenCode requires API key"
test_opencode_validates_with_api_key && echo "✓ OpenCode validates with API key"
test_opencode_validates_with_zsh_ai_key && echo "✓ OpenCode validates with ZSH_AI_OPENCODE_API_KEY"
test_opencode_key_takes_precedence && echo "✓ OpenCode ZSH_AI_OPENCODE_API_KEY takes precedence"
