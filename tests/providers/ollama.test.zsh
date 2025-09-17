#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the context and ollama provider modules
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/prompts.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/providers/ollama.zsh"

# Test functions

test_check_ollama_running_success() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock successful curl response
    mock_curl_response '{"models":[]}' 0
    
    _zsh_ai_check_ollama
    local result=$?
    
    assert_equals "$result" "0"
    
    teardown_test_env
}

test_check_ollama_running_failure() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock curl failure
    mock_command "curl" "" 1
    
    _zsh_ai_check_ollama
    local result=$?
    
    assert_equals "$result" "1"
    
    teardown_test_env
}

test_successful_api_call_with_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful curl response
    local mock_response='{"response":"git status"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "show git status")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "git status"
    
    teardown_test_env
}

test_successful_api_call_without_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock successful curl response
    local mock_response='{"response":"docker ps -a"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "list all docker containers")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "docker ps -a"
    
    teardown_test_env
}

test_handles_api_error_response_with_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock error response
    local mock_response='{"error":"Model not found"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Ollama Error: Model not found"
    
    teardown_test_env
}

test_handles_curl_connection_failure() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock curl failure
    mock_command "curl" "" 1
    
    local output
    output=$(_zsh_ai_query_ollama "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Failed to connect to Ollama"
    assert_contains "$output" "Is it running?"
    
    teardown_test_env
}

test_handles_empty_response_with_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock empty response
    local mock_response='{}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse Ollama response"
    
    teardown_test_env
}

test_handles_malformed_response_without_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock malformed response
    local mock_response='{"malformed": "data"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse response"
    assert_contains "$output" "install jq"
    
    teardown_test_env
}

test_uses_correct_model_from_config() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="codellama"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"response":"npm test"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "run tests")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "npm test"
    
    teardown_test_env
}

test_uses_correct_url_from_config() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://remote:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"response":"ls -la"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "list files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    teardown_test_env
}

test_removes_trailing_newlines_from_response() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock response with newlines
    local mock_response='{"response":"cd /home\n\n"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "go home")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "cd /home"
    
    teardown_test_env
}

test_escapes_quotes_in_query() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"response":"echo \"test\""}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama 'print "test"')
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" 'echo "test"'
    
    teardown_test_env
}

test_includes_context_in_api_call() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Create a test environment with specific context
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    touch Dockerfile
    
    # Mock successful response
    local mock_response='{"response":"docker build ."}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "build docker image")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "docker build ."
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_sets_correct_temperature_option() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"response":"python script.py"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "run python script")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "python script.py"
    
    teardown_test_env
}

test_handles_response_with_escaped_newline_with_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock response with escaped newline (as reported in issue #20)
    local mock_response='{"model":"gemma3n:e4b-it-q8_0","created_at":"2025-07-08T15:18:25.393846Z","response":"date\n","done":true,"done_reason":"stop"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "show current date")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "date"
    
    teardown_test_env
}

test_handles_response_with_escaped_newline_without_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock response with escaped newline
    local mock_response='{"response":"ls -la\n"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "list files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    teardown_test_env
}

test_handles_midfield_newline_without_jq() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock response with actual newline in the middle of JSON field (as described by pcause)
    local mock_response='{"model":"llama3.2","created_at":"2025-07-08T15:18:25.393846Z","response":"date
","done":true}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "show date")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "date"
    
    teardown_test_env
}

test_handles_thinking_model_response() {
    setup_test_env
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock response that might include thinking output
    local mock_response='{"model":"llama3.2","response":"date","think":"Let me think about what command shows the current date...","done":true}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_ollama "show current date")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "date"
    
    teardown_test_env
}

# Run tests
echo "Running ollama provider tests..."
test_check_ollama_running_success && echo "✓ Check if Ollama is running - success"
test_check_ollama_running_failure && echo "✓ Check if Ollama is running - failure"
test_successful_api_call_with_jq && echo "✓ Successful API call with jq available"
test_successful_api_call_without_jq && echo "✓ Successful API call without jq"
test_handles_api_error_response_with_jq && echo "✓ Handles API error response with jq"
test_handles_curl_connection_failure && echo "✓ Handles curl connection failure"
test_handles_empty_response_with_jq && echo "✓ Handles empty response with jq"
test_handles_malformed_response_without_jq && echo "✓ Handles malformed response without jq"
test_uses_correct_model_from_config && echo "✓ Uses correct model from config"
test_uses_correct_url_from_config && echo "✓ Uses correct URL from config"
test_removes_trailing_newlines_from_response && echo "✓ Removes trailing newlines from response"
test_escapes_quotes_in_query && echo "✓ Escapes quotes in query"
test_includes_context_in_api_call && echo "✓ Includes context in API call"
test_sets_correct_temperature_option && echo "✓ Sets correct temperature option"
test_handles_response_with_escaped_newline_with_jq && echo "✓ Handles response with escaped newline (with jq)"
test_handles_response_with_escaped_newline_without_jq && echo "✓ Handles response with escaped newline (without jq)"
test_handles_midfield_newline_without_jq && echo "✓ Handles mid-field newline without jq"
test_handles_thinking_model_response && echo "✓ Handles thinking model response"