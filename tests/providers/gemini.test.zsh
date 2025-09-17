#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the context and gemini provider modules
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/prompts.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/providers/gemini.zsh"

# Test functions

test_default_model_configuration() {
    setup_test_env
    
    # Source config to get default values
    source "$PLUGIN_DIR/lib/config.zsh"
    
    assert_equals "$ZSH_AI_GEMINI_MODEL" "gemini-2.0-flash"
    
    teardown_test_env
}

test_validation_fails_without_api_key() {
    setup_test_env
    unset GEMINI_API_KEY
    export ZSH_AI_PROVIDER="gemini"
    
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    
    assert_equals "$result" "1"
    
    teardown_test_env
}

test_validation_succeeds_with_api_key() {
    setup_test_env
    export GEMINI_API_KEY="test-key"
    export ZSH_AI_PROVIDER="gemini"
    
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    
    assert_equals "$result" "0"
    
    teardown_test_env
}

test_routes_queries_to_gemini_provider() {
    setup_test_env
    export GEMINI_API_KEY="test-key"
    export ZSH_AI_PROVIDER="gemini"
    
    # Mock the gemini query function
    _zsh_ai_query_gemini() {
        echo "gemini-response"
    }
    
    local output=$(_zsh_ai_query "test query")
    assert_equals "$output" "gemini-response"
    
    teardown_test_env
}

test_gemini_query_function_exists() {
    setup_test_env
    export GEMINI_API_KEY="test-key"
    export ZSH_AI_PROVIDER="gemini"
    
    # Load the provider
    source "$PLUGIN_DIR/lib/providers/gemini.zsh"
    
    # Check if function exists
    if type _zsh_ai_query_gemini >/dev/null 2>&1; then
        local result=0
    else
        local result=1
    fi
    
    assert_equals "$result" "0"
    
    teardown_test_env
}

test_successful_api_call_with_jq() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock successful curl response
    local mock_response='{"candidates":[{"content":{"parts":[{"text":"git status"}]}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "show git status")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "git status"
    
    teardown_test_env
}

test_successful_api_call_without_jq() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock successful curl response
    local mock_response='{"candidates":[{"content":{"parts":[{"text":"ls -la"}]}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "list files")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"
    
    teardown_test_env
}

test_handles_api_error_response() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock error response
    local mock_response='{"error":{"message":"Invalid API key"}}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "API Error: Invalid API key"
    
    teardown_test_env
}

test_handles_curl_connection_failure() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock curl failure
    mock_command "curl" "" 1
    
    local output
    output=$(_zsh_ai_query_gemini "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Failed to connect to Google AI API"
    
    teardown_test_env
}

test_handles_empty_response() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock empty response
    local mock_response='{}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse response"
    
    teardown_test_env
}

test_handles_response_with_escaped_newline_with_jq() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as available
    mock_jq "true"
    
    # Mock response with escaped newline
    local mock_response='{"candidates":[{"content":{"parts":[{"text":"git status\n"}]}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "check git status")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "git status"
    
    teardown_test_env
}

test_handles_response_with_escaped_newline_without_jq() {
    setup_test_env
    export GEMINI_API_KEY="test-api-key"
    
    # Mock jq as unavailable
    mock_jq "false"
    
    # Mock response with escaped newline
    local mock_response='{"candidates":[{"content":{"parts":[{"text":"docker ps\n"}]}}]}'
    mock_curl_response "$mock_response" 0
    
    local output
    output=$(_zsh_ai_query_gemini "list docker containers")
    local result=$?
    
    assert_equals "$result" "0"
    assert_equals "$output" "docker ps"
    
    teardown_test_env
}

# Run tests
echo "Running gemini provider tests..."
test_default_model_configuration && echo "✓ Default model configuration"
test_validation_fails_without_api_key && echo "✓ Validation fails without API key"
test_validation_succeeds_with_api_key && echo "✓ Validation succeeds with API key"
test_routes_queries_to_gemini_provider && echo "✓ Routes queries to gemini provider"
test_gemini_query_function_exists && echo "✓ Gemini query function exists"
test_successful_api_call_with_jq && echo "✓ Successful API call with jq available"
test_successful_api_call_without_jq && echo "✓ Successful API call without jq"
test_handles_api_error_response && echo "✓ Handles API error response"
test_handles_curl_connection_failure && echo "✓ Handles curl connection failure"
test_handles_empty_response && echo "✓ Handles empty response"
test_handles_response_with_escaped_newline_with_jq && echo "✓ Handles response with escaped newline (with jq)"
test_handles_response_with_escaped_newline_without_jq && echo "✓ Handles response with escaped newline (without jq)"