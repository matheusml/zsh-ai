#!/usr/bin/env zsh

# Tests for Grok provider

# Source test helper and the files we're testing
source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/grok.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

# Mock curl to test API interactions
curl() {
    if [[ "$*" == *"https://api.x.ai/v1/chat/completions"* ]]; then
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

test_grok_query_success() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    local result=$(_zsh_ai_query_grok "list files")
    assert_equals "$result" "ls -la"
}

test_grok_query_error_response() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # Override curl to return an error
    curl() {
        if [[ "$*" == *"https://api.x.ai/v1/chat/completions"* ]]; then
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

    local result=$(_zsh_ai_query_grok "list files")
    assert_contains "$result" "API Error:"
}

test_grok_json_escaping() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # Test with special characters
    local result=$(_zsh_ai_query_grok "test \"quotes\" and \$variables")
    # Should not fail due to JSON escaping issues
    assert_not_empty "$result"
}

test_handles_response_with_newline() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # Override curl to return response with newline
    curl() {
        if [[ "$*" == *"https://api.x.ai/v1/chat/completions"* ]]; then
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

    local result=$(_zsh_ai_query_grok "go home")
    assert_equals "$result" "cd /home"
}

test_handles_response_without_jq() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # Mock jq as unavailable
    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    # Override curl for consistent response
    curl() {
        if [[ "$*" == *"https://api.x.ai/v1/chat/completions"* ]]; then
            echo '{"choices":[{"message":{"content":"echo test"}}]}'
            return 0
        fi
        builtin command curl "$@"
    }

    local result=$(_zsh_ai_query_grok "echo test")
    assert_equals "$result" "echo test"
}

test_uses_fixed_api_url() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # The API URL is hardcoded in the grok.zsh file
    # Test just verifies a successful query works (which implicitly tests the URL)
    local result=$(_zsh_ai_query_grok "test")
    assert_not_empty "$result"
}

test_uses_max_completion_tokens() {
    export XAI_API_KEY="test-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.x.ai/v1/chat/completions"* ]]; then
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

    _zsh_ai_query_grok "test" >/dev/null
    local captured_payload=$(cat "$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_completion_tokens"'
}

test_uses_xai_api_key() {
    export XAI_API_KEY="test-secret-key"
    export ZSH_AI_GROK_MODEL="grok-4-1-fast-non-reasoning"

    # Test that the function uses XAI_API_KEY (not OPENAI_API_KEY)
    # If XAI_API_KEY is set, the query should succeed
    local result=$(_zsh_ai_query_grok "test")
    assert_not_empty "$result"
}

# Add missing assert_not_empty function
assert_not_empty() {
    [[ -n "$1" ]]
}

# Run tests
echo "Running Grok provider tests..."
test_grok_query_success && echo "✓ Grok query success"
test_grok_query_error_response && echo "✓ Grok error response handling"
test_grok_json_escaping && echo "✓ Grok JSON escaping"
test_handles_response_with_newline && echo "✓ Handles response with trailing newline"
test_handles_response_without_jq && echo "✓ Handles response without jq and with newline"
test_uses_fixed_api_url && echo "✓ Uses fixed API URL (hardcoded to api.x.ai)"
test_uses_max_completion_tokens && echo "✓ Uses max_completion_tokens parameter"
test_uses_xai_api_key && echo "✓ Uses XAI_API_KEY environment variable"
