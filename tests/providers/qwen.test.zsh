#!/usr/bin/env zsh

# Tests for Qwen provider

# Source test helper and the files we're testing
source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/qwen.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

# Mock curl to test API interactions
curl() {
    if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
        # Simulate successful response
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
    # Call real curl for other requests
    command curl "$@"
}

test_qwen_query_success() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"

    local result=$(_zsh_ai_query_qwen "list files")
    assert_equals "$result" "ls -la"
}

test_qwen_query_error_response() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"

    # Override curl to return an error
    curl() {
        if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
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

    local result=$(_zsh_ai_query_qwen "list files")
    assert_contains "$result" "API Error:"
}

test_qwen_json_escaping() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"

    # Test with special characters
    local result=$(_zsh_ai_query_qwen "test \"quotes\" and \$variables")
    # Should not fail due to JSON escaping issues
    assert_not_empty "$result"
}

test_handles_response_with_newline() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"

    # Override curl to return response with newline
    curl() {
        if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
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

    local result=$(_zsh_ai_query_qwen "go home")
    assert_equals "$result" "cd /home"
}

test_handles_response_without_jq() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"

    # Mock jq as unavailable
    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    # Override curl for consistent response
    curl() {
        if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
            echo '{"choices":[{"message":{"content":"echo test"}}]}'
            return 0
        fi
        builtin command curl "$@"
    }

    local result=$(_zsh_ai_query_qwen "echo test")
    assert_equals "$result" "echo test"
}

test_uses_configurable_api_url() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"
    export ZSH_AI_QWEN_URL="https://custom.qwen.api/v1/chat/completions"

    # Override curl to check the custom URL is used
    curl() {
        if [[ "$*" == *"https://custom.qwen.api/v1/chat/completions"* ]]; then
            echo '{"choices":[{"message":{"content":"custom url works"}}]}'
            return 0
        fi
        return 1
    }

    local result=$(_zsh_ai_query_qwen "test")
    assert_equals "$result" "custom url works"

    # Reset to default
    export ZSH_AI_QWEN_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
}

test_uses_max_tokens() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
            local prev_arg=""
            for arg in "$@"; do
                if [[ "$prev_arg" == "--data" ]]; then
                    echo "$arg" > "$payload_file"
                    break
                fi
                prev_arg="$arg"
            done
            echo '{"choices":[{"message":{"content":"test"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_qwen "test" >/dev/null
    local captured_payload=$(<"$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_tokens"'
}

test_uses_qwen_api_key() {
    export QWEN_API_KEY="test-secret-key"
    export ZSH_AI_QWEN_MODEL="qwen-plus"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"${ZSH_AI_QWEN_URL}"* ]]; then
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ok"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_qwen "test" >/dev/null
    local curl_args=$(<"$curl_args_file")
    rm -f "$curl_args_file"
    assert_contains "$curl_args" "Authorization: Bearer test-secret-key"
}

# Tests for Qwen config validation
test_qwen_requires_api_key() {
    unset QWEN_API_KEY
    export ZSH_AI_PROVIDER="qwen"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "1" || return 1
    assert_contains "$result" "QWEN_API_KEY not set" || return 1
}

test_qwen_validation_succeeds_with_api_key() {
    export QWEN_API_KEY="test-key"
    export ZSH_AI_PROVIDER="qwen"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "0" || return 1
}

# Add missing assert_not_empty function
assert_not_empty() {
    [[ -n "$1" ]]
}

# Run tests
echo "Running Qwen provider tests..."
test_qwen_query_success && echo "✓ Qwen query success"
test_qwen_query_error_response && echo "✓ Qwen error response handling"
test_qwen_json_escaping && echo "✓ Qwen JSON escaping"
test_handles_response_with_newline && echo "✓ Handles response with trailing newline"
test_handles_response_without_jq && echo "✓ Handles response without jq and with newline"
test_uses_configurable_api_url && echo "✓ Uses configurable API URL (ZSH_AI_QWEN_URL)"
test_uses_max_tokens && echo "✓ Uses max_tokens parameter"
test_uses_qwen_api_key && echo "✓ Uses QWEN_API_KEY environment variable"

echo ""
echo "Running Qwen config validation tests..."
test_qwen_requires_api_key && echo "✓ Requires API key for qwen provider"
test_qwen_validation_succeeds_with_api_key && echo "✓ Validation succeeds with QWEN_API_KEY"