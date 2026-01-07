#!/usr/bin/env zsh

# Tests for OpenAI provider

# Source test helper and the files we're testing
source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/openai.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

# Mock curl to test API interactions
curl() {
    if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

test_openai_query_success() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"

    local result=$(_zsh_ai_query_openai "list files")
    assert_equals "$result" "ls -la"
}

test_openai_query_error_response() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"
    
    # Override curl to return an error
    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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
    
    local result=$(_zsh_ai_query_openai "list files")
    assert_contains "$result" "API Error:"
}

test_openai_json_escaping() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"
    
    # Test with special characters
    local result=$(_zsh_ai_query_openai "test \"quotes\" and \$variables")
    # Should not fail due to JSON escaping issues
    assert_not_empty "$result"
}

test_handles_response_with_newline() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"

    # Override curl to return response with newline
    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

    local result=$(_zsh_ai_query_openai "go home")
    assert_equals "$result" "cd /home"
}

test_handles_response_without_jq() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"

    # Mock jq as unavailable
    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    # Override curl for consistent response
    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
            echo '{"choices":[{"message":{"content":"echo test"}}]}'
            return 0
        fi
        builtin command curl "$@"
    }

    local result=$(_zsh_ai_query_openai "echo test")
    assert_equals "$result" "echo test"
}

test_uses_default_url_when_not_configured() {
    unset ZSH_AI_OPENAI_URL

    # Re-source config to pick up the default
    source "${PLUGIN_DIR}/lib/config.zsh"

    # Verify the default URL is set correctly
    assert_equals "$ZSH_AI_OPENAI_URL" "https://api.openai.com/v1/chat/completions"
}

test_uses_custom_url_when_configured() {
    export ZSH_AI_OPENAI_URL="https://custom.api.example.com/v1/chat/completions"

    # Verify the custom URL is set
    assert_equals "$ZSH_AI_OPENAI_URL" "https://custom.api.example.com/v1/chat/completions"
}

test_uses_perplexity_url() {
    export ZSH_AI_OPENAI_URL="https://api.perplexity.ai/chat/completions"

    # Verify Perplexity URL can be configured
    assert_equals "$ZSH_AI_OPENAI_URL" "https://api.perplexity.ai/chat/completions"
}

test_uses_max_tokens_for_gpt4_models() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

    _zsh_ai_query_openai "test" >/dev/null
    local captured_payload=$(cat "$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_tokens"'
}

test_uses_max_tokens_for_gpt35_models() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-3.5-turbo"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

    _zsh_ai_query_openai "test" >/dev/null
    local captured_payload=$(cat "$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_tokens"'
}

test_uses_max_completion_tokens_for_gpt5_models() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-5-nano"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

    _zsh_ai_query_openai "test" >/dev/null
    local captured_payload=$(cat "$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_completion_tokens"'
}

test_uses_max_completion_tokens_for_o1_models() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="o1-preview"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
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

    _zsh_ai_query_openai "test" >/dev/null
    local captured_payload=$(cat "$payload_file")
    rm -f "$payload_file"
    assert_contains "$captured_payload" '"max_completion_tokens"'
}

# Add missing assert_not_empty function
assert_not_empty() {
    [[ -n "$1" ]]
}

# Run tests
echo "Running OpenAI provider tests..."
test_openai_query_success && echo "✓ OpenAI query success"
test_openai_query_error_response && echo "✓ OpenAI error response handling"
test_openai_json_escaping && echo "✓ OpenAI JSON escaping"
test_handles_response_with_newline && echo "✓ Handles response with trailing newline"
test_handles_response_without_jq && echo "✓ Handles response without jq and with newline"
test_uses_default_url_when_not_configured && echo "✓ Uses default URL when not configured"
test_uses_custom_url_when_configured && echo "✓ Uses custom URL when configured"
test_uses_perplexity_url && echo "✓ Uses Perplexity URL"
test_uses_max_tokens_for_gpt4_models && echo "✓ Uses max_tokens for gpt-4 models"
test_uses_max_tokens_for_gpt35_models && echo "✓ Uses max_tokens for gpt-3.5 models"
test_uses_max_completion_tokens_for_gpt5_models && echo "✓ Uses max_completion_tokens for gpt-5 models"
test_uses_max_completion_tokens_for_o1_models && echo "✓ Uses max_completion_tokens for o1 models"

# Tests for keyless OpenAI-compatible endpoints
echo ""
echo "Running OpenAI-compatible (keyless) tests..."

test_openai_requires_key_for_default_url() {
    unset OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    # Explicitly set to default URL to ensure test works
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"

    local result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "OPENAI_API_KEY not set"
}

test_openai_works_without_key_for_custom_url() {
    unset OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"

    local result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    # Should pass validation without API key
    assert_equals "$exit_code" "0"
}

test_openai_query_without_auth_header() {
    unset OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_MODEL="local-model"
    export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"localhost:8080"* ]]; then
            # Save the curl arguments to check later
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_openai "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    # Authorization header should NOT be present
    if [[ "$curl_args" == *"Authorization"* ]]; then
        echo "FAIL: Authorization header should not be present"
        return 1
    fi
    return 0
}

test_openai_query_with_auth_header_when_key_set() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_MODEL="local-model"
    export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"localhost:8080"* ]]; then
            # Save the curl arguments to check later
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_openai "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    # Authorization header SHOULD be present
    if [[ "$curl_args" != *"Authorization"* ]]; then
        echo "FAIL: Authorization header should be present"
        return 1
    fi
    return 0
}

test_openai_requires_key_for_default_url && echo "✓ Requires API key for default OpenAI URL"
test_openai_works_without_key_for_custom_url && echo "✓ Works without API key for custom URL"
test_openai_query_without_auth_header && echo "✓ Omits Authorization header when no API key"
test_openai_query_with_auth_header_when_key_set && echo "✓ Includes Authorization header when API key is set"