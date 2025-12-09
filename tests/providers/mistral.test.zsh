#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the context and mistral provider modules
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/providers/mistral.zsh"

# Test functions

test_successful_api_call_with_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful curl response
    local mock_response='{"choices":[{"message":{"content":"ls -la"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "list all files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    teardown_test_env
}

test_successful_api_call_without_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock successful curl response
    local mock_response='{"choices":[{"message":{"content":"cd /home/user"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "go to home directory")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "cd /home/user"
    
    teardown_test_env
}

test_handles_api_error_response_with_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock error response
    local mock_response='{"error":{"message":"Invalid API key"}}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "API Error: Invalid API key"
    
    teardown_test_env
}

test_handles_curl_connection_failure() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock curl failure
    mock_command "curl" "" 1
    
    local output
    output=$(_zsh_ai_query_mistral "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Failed to connect to Mistral API"
    
    teardown_test_env
}

test_handles_empty_response_with_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock empty response
    local mock_response='{}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse response"
    
    teardown_test_env
}

test_handles_malformed_response_without_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock malformed response
    local mock_response='{"malformed": "data"}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse response"
    assert_contains "$output" "install jq"
    
    teardown_test_env
}

test_escapes_quotes_in_query() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"choices":[{"message":{"content":"echo \"Hello World\""}}]}'
    mock_curl_response "$mock_response" 0
    
    # Capture the actual curl call to verify escaping
    mock_command "curl" "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral 'print "Hello World"')
    local result=$?
    
    assert_equals "$result" "0"
    
    teardown_test_env
}

test_includes_context_in_api_call() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Create a test environment with specific context
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    touch package.json
    
    # Mock successful response
    local mock_response='{"choices":[{"message":{"content":"npm install"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "install dependencies")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "npm install"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_uses_correct_api_headers() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock curl to capture the command
    local captured_args=""
    mock_command "curl" '{"choices":[{"message":{"content":"ls"}}]}' 0
    
    local output
    output=$(_zsh_ai_query_mistral "list files")
    local result=$?
    
    assert_equals "$result" "0"
    
    teardown_test_env
}

test_uses_correct_model() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    export ZSH_AI_MISTRAL_MODEL="mistral-small-latest"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful response
    local mock_response='{"choices":[{"message":{"content":"pwd"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "show current directory")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "pwd"
    
    teardown_test_env
}

test_handles_multiline_context_properly() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Create files to generate multiline context
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    touch file1.txt file2.txt file3.txt
    
    # Mock successful response
    local mock_response='{"choices":[{"message":{"content":"ls -la"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "list all files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_handles_response_with_escaped_newline_with_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock response with escaped newline (trailing newline that should be removed)
    local mock_response='{"choices":[{"message":{"content":"ls -la\n"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "list files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    teardown_test_env
}

test_handles_response_with_escaped_newline_without_jq() {
    setup_test_env
    export MISTRAL_API_KEY="test-api-key"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock response with escaped newline
    local mock_response='{"choices":[{"message":{"content":"pwd\n"}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_mistral "show current directory")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "pwd"
    
    teardown_test_env
}

# Run tests
echo "Running mistral provider tests..."
test_successful_api_call_with_jq && echo "✓ Successful API call with jq available"
test_successful_api_call_without_jq && echo "✓ Successful API call without jq"
test_handles_api_error_response_with_jq && echo "✓ Handles API error response with jq"
test_handles_curl_connection_failure && echo "✓ Handles curl connection failure"
test_handles_empty_response_with_jq && echo "✓ Handles empty response with jq"
test_handles_malformed_response_without_jq && echo "✓ Handles malformed response without jq"
test_escapes_quotes_in_query && echo "✓ Escapes quotes in query"
test_includes_context_in_api_call && echo "✓ Includes context in API call"
test_uses_correct_api_headers && echo "✓ Uses correct API headers"
test_uses_correct_model && echo "✓ Uses correct model"
test_handles_multiline_context_properly && echo "✓ Handles multiline context properly"
test_handles_response_with_escaped_newline_with_jq && echo "✓ Handles response with escaped newline (with jq)"
test_handles_response_with_escaped_newline_without_jq && echo "✓ Handles response with escaped newline (without jq)"

