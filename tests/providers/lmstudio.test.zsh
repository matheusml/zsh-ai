#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the context and LM Studio provider modules
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/providers/lmstudio.zsh"

# Test functions

test_default_config() {
    assert_equals "$ZSH_AI_LMSTUDIO_URL" "http://127.0.0.1:1234/v1/chat/completions"
    assert_not_empty "$ZSH_AI_LMSTUDIO_MODEL"
}

test_check_lmstudio_running_success() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"

    mock_curl_response '{"data":[]}' 0

    _zsh_ai_check_lmstudio
    assert_equals "$?" "0"

    teardown_test_env
}

test_check_lmstudio_queries_models_endpoint() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    local request_dir=$(mktemp -d)

    curl() {
        local arg
        for arg in "$@"; do
            [[ "$arg" == http://* ]] && printf '%s' "$arg" > "$request_dir/url"
        done
        return 0
    }

    _zsh_ai_check_lmstudio
    assert_equals "$(<"$request_dir/url")" "http://127.0.0.1:1234/v1/models"

    rm -rf "$request_dir"
    teardown_test_env
}

test_check_lmstudio_failure() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_MODEL="ornith-1.5-9b"
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"

    mock_command "curl" "" 7

    local output
    output=$(_zsh_ai_check_lmstudio)
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "LM Studio is not reachable"
    assert_contains "$output" "ornith-1.5-9b"
    assert_contains "$output" "full chat-completions URL"

    teardown_test_env
}

test_request_uses_chat_payload() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_MODEL="ornith-1.5-9b"
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    local request_dir=$(mktemp -d)

    curl() {
        local arg previous=""
        for arg in "$@"; do
            if [[ "$previous" == "--data" ]]; then
                printf '%s' "$arg" > "$request_dir/payload"
            elif [[ "$arg" == http://* ]]; then
                printf '%s' "$arg" > "$request_dir/url"
            fi
            previous="$arg"
        done
        printf '%s' '{"choices":[{"message":{"content":"git status"}}]}'
        return 0
    }

    local output
    output=$(_zsh_ai_query_lmstudio 'show "git" status')
    local result=$?
    local payload=$(<"$request_dir/payload")

    assert_equals "$result" "0"
    assert_equals "$output" "git status"
    assert_equals "$(<"$request_dir/url")" "http://127.0.0.1:1234/v1/chat/completions"
    assert_contains "$payload" '"model": "ornith-1.5-9b"'
    assert_contains "$payload" '"messages": ['
    assert_contains "$payload" '"role": "system"'
    assert_contains "$payload" '"role": "user"'
    assert_contains "$payload" 'show \"git\" status'
    assert_contains "$payload" '"max_tokens": 256'
    assert_not_contains "$payload" '"prompt"'

    rm -rf "$request_dir"
    teardown_test_env
}

test_successful_api_call_with_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_MODEL="ornith-1.5-9b"
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"choices":[{"message":{"content":"git status"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "show git status")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "git status"

    teardown_test_env
}

test_successful_api_call_without_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_MODEL="ornith-1.5-9b"
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "false"
    mock_curl_response '{"choices":[{"message":{"content":"docker ps -a"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "list all docker containers")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "docker ps -a"

    teardown_test_env
}

test_handles_api_error_with_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"error":{"message":"Model not loaded"}}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "LM Studio Error: Model not loaded"

    teardown_test_env
}

test_handles_api_error_without_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "false"
    mock_curl_response '{"error":{"message":"Model not loaded"}}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "LM Studio Error: Model not loaded"

    teardown_test_env
}

test_handles_curl_connection_failure() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_command "curl" "" 7

    local output
    output=$(_zsh_ai_query_lmstudio "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Failed to connect to LM Studio"

    teardown_test_env
}

test_handles_empty_response_with_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse LM Studio response"

    teardown_test_env
}

test_handles_empty_text_without_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "false"
    mock_curl_response '{"choices":[{"message":{"content":"\n\n"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "empty command"

    teardown_test_env
}

test_strips_reasoning_block_with_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"choices":[{"message":{"content":"<think>\nThe user wants the date.\n</think>\n\ndate"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "show current date")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "date"

    teardown_test_env
}

test_strips_unclosed_reasoning_without_jq() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "false"
    mock_curl_response '{"choices":[{"message":{"content":"echo $EPOCHSECONDS\n\n<think>\nThe user wants me to show the date."}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "show current date")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "echo \$EPOCHSECONDS"

    teardown_test_env
}

test_strips_code_fences() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"choices":[{"message":{"content":"```zsh\nls -la\n```"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "list files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"

    teardown_test_env
}

test_uses_configured_model_and_url() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_MODEL="qwen/qwen3.5-9b"
    export ZSH_AI_LMSTUDIO_URL="http://remote:9000/v1/chat/completions"
    mock_jq "true"
    local request_dir=$(mktemp -d)

    curl() {
        local arg previous=""
        for arg in "$@"; do
            if [[ "$previous" == "--data" ]]; then
                printf '%s' "$arg" > "$request_dir/payload"
            elif [[ "$arg" == http://* ]]; then
                printf '%s' "$arg" > "$request_dir/url"
            fi
            previous="$arg"
        done
        printf '%s' '{"choices":[{"message":{"content":"ls"}}]}'
        return 0
    }

    _zsh_ai_query_lmstudio "list files" >/dev/null
    assert_equals "$(<"$request_dir/url")" "http://remote:9000/v1/chat/completions"
    assert_contains "$(<"$request_dir/payload")" '"model": "qwen/qwen3.5-9b"'

    rm -rf "$request_dir"
    teardown_test_env
}

test_closing_reasoning_tag_only_is_empty() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"choices":[{"message":{"content":"</think>"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "git commit for each file")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "empty command"

    teardown_test_env
}

test_strips_leading_assistant_label() {
    setup_test_env
    export ZSH_AI_LMSTUDIO_URL="http://127.0.0.1:1234/v1/chat/completions"
    mock_jq "true"
    mock_curl_response '{"choices":[{"message":{"content":"Assistant: ls -laSh"}}]}' 0

    local output
    output=$(_zsh_ai_query_lmstudio "list files sorted by size")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "ls -laSh"

    teardown_test_env
}

# Run tests
echo "Running LM Studio provider tests..."
run_test "Default LM Studio model and URL" test_default_config
run_test "Check if LM Studio is running - success" test_check_lmstudio_running_success
run_test "Check queries the models endpoint" test_check_lmstudio_queries_models_endpoint
run_test "Check if LM Studio is running - failure" test_check_lmstudio_failure
run_test "Request uses chat payload" test_request_uses_chat_payload
run_test "Successful API call with jq available" test_successful_api_call_with_jq
run_test "Successful API call without jq" test_successful_api_call_without_jq
run_test "Handles API error response with jq" test_handles_api_error_with_jq
run_test "Handles API error response without jq" test_handles_api_error_without_jq
run_test "Handles curl connection failure" test_handles_curl_connection_failure
run_test "Handles empty response with jq" test_handles_empty_response_with_jq
run_test "Handles empty text without jq" test_handles_empty_text_without_jq
run_test "Strips reasoning block (with jq)" test_strips_reasoning_block_with_jq
run_test "Strips unclosed reasoning (without jq)" test_strips_unclosed_reasoning_without_jq
run_test "Strips code fences" test_strips_code_fences
run_test "Uses configured model and URL" test_uses_configured_model_and_url
run_test "Closing reasoning tag alone is an empty command" test_closing_reasoning_tag_only_is_empty
run_test "Strips leading Assistant label" test_strips_leading_assistant_label
finish_tests
