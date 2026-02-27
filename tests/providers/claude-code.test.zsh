#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the context and claude-code provider modules
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/providers/claude-code.zsh"

# Test functions

test_check_claude_code_installed_success() {
    setup_test_env

    # Mock claude as available
    mock_command "claude" "" 0

    _zsh_ai_check_claude_code
    local result=$?

    assert_equals "$result" "0"

    teardown_test_env
}

test_check_claude_code_installed_failure() {
    setup_test_env

    # Ensure claude is not found
    command() {
        if [[ "$1" == "-v" ]] && [[ "$2" == "claude" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    _zsh_ai_check_claude_code
    local result=$?

    assert_equals "$result" "1"

    teardown_test_env
}

test_successful_query() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI to return a command
    mock_command "claude" "ls -la" 0

    local output
    output=$(_zsh_ai_query_claude_code "list all files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"

    teardown_test_env
}

test_handles_cli_failure() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI failure
    mock_command "claude" "" 1

    local output
    output=$(_zsh_ai_query_claude_code "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Failed to run claude CLI"

    teardown_test_env
}

test_surfaces_cli_error_output() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI failure with error message (e.g. auth failure)
    mock_command "claude" "Not authenticated. Run claude login." 1

    local output
    output=$(_zsh_ai_query_claude_code "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Not authenticated"

    teardown_test_env
}

test_handles_empty_response() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI returning empty string
    mock_command "claude" "" 0

    local output
    output=$(_zsh_ai_query_claude_code "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Empty response from claude CLI"

    teardown_test_env
}

test_strips_markdown_code_fences() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI returning response wrapped in markdown fences
    claude() {
        printf '%s\n' '```sh' 'git status' '```'
        return 0
    }

    local output
    output=$(_zsh_ai_query_claude_code "show git status")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "git status"

    teardown_test_env
}

test_removes_trailing_whitespace() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI returning response with trailing whitespace
    claude() {
        printf "docker ps -a   "
        return 0
    }

    local output
    output=$(_zsh_ai_query_claude_code "list docker containers")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "docker ps -a"

    teardown_test_env
}

test_uses_model_from_config() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-sonnet-4-5"

    # Mock claude CLI - just verify it runs
    mock_command "claude" "npm test" 0

    local output
    output=$(_zsh_ai_query_claude_code "run tests")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "npm test"

    teardown_test_env
}

test_includes_context_in_query() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Create a test environment with specific context
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    touch Dockerfile

    # Mock claude CLI
    mock_command "claude" "docker build ." 0

    local output
    output=$(_zsh_ai_query_claude_code "build docker image")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "docker build ."

    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_escapes_quotes_in_query() {
    setup_test_env
    export ZSH_AI_CLAUDE_CODE_MODEL="claude-haiku-4-5"

    # Mock claude CLI
    mock_command "claude" 'echo "test"' 0

    local output
    output=$(_zsh_ai_query_claude_code 'print "test"')
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" 'echo "test"'

    teardown_test_env
}

# Run tests
echo "Running claude-code provider tests..."
test_check_claude_code_installed_success && echo "✓ Check if claude CLI is installed - success"
test_check_claude_code_installed_failure && echo "✓ Check if claude CLI is installed - failure"
test_successful_query && echo "✓ Successful query"
test_handles_cli_failure && echo "✓ Handles CLI failure"
test_surfaces_cli_error_output && echo "✓ Surfaces CLI error output"
test_handles_empty_response && echo "✓ Handles empty response"
test_strips_markdown_code_fences && echo "✓ Strips markdown code fences"
test_removes_trailing_whitespace && echo "✓ Removes trailing whitespace"
test_uses_model_from_config && echo "✓ Uses model from config"
test_includes_context_in_query && echo "✓ Includes context in query"
test_escapes_quotes_in_query && echo "✓ Escapes quotes in query"
