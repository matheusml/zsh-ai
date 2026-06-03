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
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"

    local result=$(_zsh_ai_query_openai "list files")
    assert_equals "$result" "ls -la"
}

test_openai_query_error_response() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"
    
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
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"
    
    # Test with special characters
    local result=$(_zsh_ai_query_openai "test \"quotes\" and \$variables")
    # Should not fail due to JSON escaping issues
    assert_not_empty "$result"
}

test_builds_system_prompt_from_raw_context() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-4o-mini"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    _zsh_ai_build_context() {
        printf '%s\n%s' 'Current directory: /tmp/"quoted"' 'Files: slash\path.txt'
    }

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
            local prev_arg=""
            for arg in "$@"; do
                if [[ "$prev_arg" == "--data" ]]; then
                    printf '%s' "$arg" > "$payload_file"
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

    # Restore the real context builder for the rest of the file.
    source "${PLUGIN_DIR}/lib/context.zsh"

    local decoded_system_prompt=$(printf "%s" "$captured_payload" | perl -MJSON::PP -0777 -ne 'print decode_json($_)->{messages}->[0]->{content}')

    assert_contains "$decoded_system_prompt" 'Current directory: /tmp/"quoted"'

    if ! printf '%s' "$decoded_system_prompt" | grep -Fq 'Files: slash\path.txt'; then
        printf '%s\n' "Expected decoded system prompt to contain literal backslash context"
        TEST_FAILED=1
    fi
    if printf '%s' "$decoded_system_prompt" | grep -Fq '\"quoted\"'; then
        printf '%s\n' "Expected decoded system prompt to contain raw quotes, not escaped quotes"
        TEST_FAILED=1
    fi
    if printf '%s' "$decoded_system_prompt" | grep -Fq 'slash\\path.txt'; then
        printf '%s\n' "Expected decoded system prompt to contain one backslash, not two"
        TEST_FAILED=1
    fi
}

test_handles_response_with_newline() {
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"
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
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"

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

capture_openai_payload_for_model() {
    local model="$1"
    export OPENAI_API_KEY="test-key"
    export ZSH_AI_OPENAI_MODEL="$model"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local payload_file=$(mktemp)

    curl() {
        if [[ "$*" == *"https://api.openai.com/v1/chat/completions"* ]]; then
            local prev_arg=""
            for arg in "$@"; do
                if [[ "$prev_arg" == "--data" ]]; then
                    printf '%s' "$arg" > "$payload_file"
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
    printf "%s" "$captured_payload"
}

test_uses_max_tokens_for_gpt4_models() {
    local captured_payload=$(capture_openai_payload_for_model "gpt-4o-mini")
    assert_contains "$captured_payload" '"max_tokens"'
}

test_uses_max_tokens_for_gpt35_models() {
    local captured_payload=$(capture_openai_payload_for_model "gpt-3.5-turbo")
    assert_contains "$captured_payload" '"max_tokens"'
}

test_uses_max_completion_tokens_for_gpt5_models() {
    local captured_payload=$(capture_openai_payload_for_model "gpt-5-nano")
    assert_contains "$captured_payload" '"max_completion_tokens"'
}

test_uses_max_completion_tokens_for_o1_models() {
    local captured_payload=$(capture_openai_payload_for_model "o1-preview")
    assert_contains "$captured_payload" '"max_completion_tokens"'
}

test_omits_temperature_for_gpt5_models() {
    local captured_payload=$(capture_openai_payload_for_model "gpt-5-mini")
    assert_not_contains "$captured_payload" '"temperature"'
}

test_includes_temperature_for_gpt4_models() {
    local captured_payload=$(capture_openai_payload_for_model "gpt-4o-mini")
    assert_contains "$captured_payload" '"temperature": 0.3'
}

# Run tests
echo "Running OpenAI provider tests..."
run_test "OpenAI query success" test_openai_query_success
run_test "OpenAI error response handling" test_openai_query_error_response
run_test "OpenAI JSON escaping" test_openai_json_escaping
run_test "Builds system prompt from raw context" test_builds_system_prompt_from_raw_context
run_test "Handles response with trailing newline" test_handles_response_with_newline
run_test "Handles response without jq and with newline" test_handles_response_without_jq
run_test "Uses default URL when not configured" test_uses_default_url_when_not_configured
run_test "Uses custom URL when configured" test_uses_custom_url_when_configured
run_test "Uses Perplexity URL" test_uses_perplexity_url
run_test "Uses max_tokens for gpt-4 models" test_uses_max_tokens_for_gpt4_models
run_test "Uses max_tokens for gpt-3.5 models" test_uses_max_tokens_for_gpt35_models
run_test "Uses max_completion_tokens for gpt-5 models" test_uses_max_completion_tokens_for_gpt5_models
run_test "Uses max_completion_tokens for o1 models" test_uses_max_completion_tokens_for_o1_models
run_test "Omits temperature for gpt-5 models" test_omits_temperature_for_gpt5_models
run_test "Includes temperature for gpt-4 models" test_includes_temperature_for_gpt4_models

# Tests for keyless OpenAI-compatible endpoints
echo ""
echo "Running OpenAI-compatible (keyless) tests..."

test_openai_requires_key_for_default_url() {
    unset OPENAI_API_KEY
    unset ZSH_AI_OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    # Explicitly set to default URL to ensure test works
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "OPENAI_API_KEY not set"
}

test_openai_works_without_key_for_custom_url() {
    unset OPENAI_API_KEY
    unset ZSH_AI_OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    # Should pass validation without API key
    assert_equals "$exit_code" "0"
}

test_openai_query_without_auth_header() {
    unset OPENAI_API_KEY
    unset ZSH_AI_OPENAI_API_KEY
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

test_openai_zsh_ai_key_passes_validation_for_default_url() {
    unset OPENAI_API_KEY
    export ZSH_AI_OPENAI_API_KEY="sk-custom-key"
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    # Should pass validation since ZSH_AI_OPENAI_API_KEY is set
    assert_equals "$exit_code" "0"
}

test_openai_zsh_ai_key_takes_precedence() {
    export OPENAI_API_KEY="original-key"
    export ZSH_AI_OPENAI_API_KEY="override-key"
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"api.openai.com"* ]]; then
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_openai "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    # Should use the override key, not the original
    if [[ "$curl_args" != *"override-key"* ]]; then
        echo "FAIL: ZSH_AI_OPENAI_API_KEY should take precedence"
        return 1
    fi
    if [[ "$curl_args" == *"original-key"* ]]; then
        echo "FAIL: OPENAI_API_KEY should not be used when ZSH_AI_OPENAI_API_KEY is set"
        return 1
    fi
    return 0
}

test_openai_falls_back_to_openai_api_key() {
    unset ZSH_AI_OPENAI_API_KEY
    export OPENAI_API_KEY="fallback-key"
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_MODEL="gpt-5-mini"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"api.openai.com"* ]]; then
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_openai "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    # Should fall back to OPENAI_API_KEY
    if [[ "$curl_args" != *"fallback-key"* ]]; then
        echo "FAIL: Should fall back to OPENAI_API_KEY when ZSH_AI_OPENAI_API_KEY is not set"
        return 1
    fi
    return 0
}

run_test "Requires API key for default OpenAI URL" test_openai_requires_key_for_default_url
run_test "Works without API key for custom URL" test_openai_works_without_key_for_custom_url
run_test "Omits Authorization header when no API key" test_openai_query_without_auth_header
run_test "Includes Authorization header when API key is set" test_openai_query_with_auth_header_when_key_set
run_test "ZSH_AI_OPENAI_API_KEY passes validation for default URL" test_openai_zsh_ai_key_passes_validation_for_default_url
run_test "ZSH_AI_OPENAI_API_KEY takes precedence over OPENAI_API_KEY" test_openai_zsh_ai_key_takes_precedence
run_test "Falls back to OPENAI_API_KEY when ZSH_AI_OPENAI_API_KEY is not set" test_openai_falls_back_to_openai_api_key
finish_tests
