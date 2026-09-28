#!/usr/bin/env zsh

# Load test helper
source "${0:A:h:h}/test_helper.zsh"

# Load the config (for _zsh_ai_is_true), utils and claude-code provider modules
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/providers/claude-code.zsh"

# Deterministic context so system prompt assertions don't depend on the cwd
_zsh_ai_build_context() {
    printf '%s' 'Test shell context'
}

# Stand in for the `claude` binary, recording how it was called.
# The provider invokes it inside a pipeline (a subshell), so the recording goes
# to files rather than variables.
mock_claude() {
    MOCK_CLAUDE_OUTPUT="$1"
    MOCK_CLAUDE_EXIT="${2:-0}"
    MOCK_CLAUDE_ARGS_FILE=$(mktemp)
    MOCK_CLAUDE_STDIN_FILE=$(mktemp)

    claude() {
        local arg joined=""
        for arg in "$@"; do
            joined+="<ARG>$arg"
        done
        printf '%s' "$joined" >| "$MOCK_CLAUDE_ARGS_FILE"
        cat >| "$MOCK_CLAUDE_STDIN_FILE"
        [[ -n "$MOCK_CLAUDE_OUTPUT" ]] && printf '%s' "$MOCK_CLAUDE_OUTPUT"
        return $MOCK_CLAUDE_EXIT
    }
}

unmock_claude() {
    unfunction claude 2>/dev/null
    [[ -n "$MOCK_CLAUDE_ARGS_FILE" ]] && rm -f "$MOCK_CLAUDE_ARGS_FILE"
    [[ -n "$MOCK_CLAUDE_STDIN_FILE" ]] && rm -f "$MOCK_CLAUDE_STDIN_FILE"
    unset MOCK_CLAUDE_OUTPUT MOCK_CLAUDE_EXIT MOCK_CLAUDE_ARGS_FILE MOCK_CLAUDE_STDIN_FILE
}

# The recorded argv, with every argument prefixed by <ARG> for exact matching
claude_args() {
    cat "$MOCK_CLAUDE_ARGS_FILE"
}

claude_stdin() {
    cat "$MOCK_CLAUDE_STDIN_FILE"
}

setup_claude_code_env() {
    setup_test_env
    export ZSH_AI_PROVIDER="claude-code"
    export ZSH_AI_CLAUDE_CODE_BIN="claude"
    export ZSH_AI_CLAUDE_CODE_MODEL="haiku"
    export ZSH_AI_CLAUDE_CODE_SAFE_MODE="true"
    export ZSH_AI_CLAUDE_CODE_ARGS=""
}

teardown_claude_code_env() {
    unmock_claude
    unset ZSH_AI_CLAUDE_CODE_BIN ZSH_AI_CLAUDE_CODE_MODEL
    unset ZSH_AI_CLAUDE_CODE_SAFE_MODE ZSH_AI_CLAUDE_CODE_ARGS
    teardown_test_env
}

# Test functions

test_successful_cli_call() {
    setup_claude_code_env
    mock_claude "ls -la" 0

    local output
    output=$(_zsh_ai_query_claude_code "list all files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"

    teardown_claude_code_env
}

test_sends_query_on_stdin() {
    setup_claude_code_env
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list all files" >/dev/null

    assert_equals "$(claude_stdin)" "list all files"
    # A query starting with '-' must not become a flag
    assert_not_contains "$(claude_args)" "<ARG>list all files"

    teardown_claude_code_env
}

test_query_starting_with_dash_is_not_a_flag() {
    setup_claude_code_env
    mock_claude "man --help" 0

    local output
    output=$(_zsh_ai_query_claude_code "--help me list files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$(claude_stdin)" "--help me list files"
    assert_not_contains "$(claude_args)" "<ARG>--help me list files"

    teardown_claude_code_env
}

test_strips_markdown_code_fences() {
    setup_claude_code_env
    mock_claude '```zsh
find . -name "*.txt"
```' 0

    local output
    output=$(_zsh_ai_query_claude_code "find text files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" 'find . -name "*.txt"'

    teardown_claude_code_env
}

test_strips_trailing_whitespace_and_blank_lines() {
    setup_claude_code_env
    mock_claude 'pwd
' 0

    local output
    output=$(_zsh_ai_query_claude_code "show current directory")

    assert_equals "$output" "pwd"

    teardown_claude_code_env
}

test_handles_cli_failure_with_message() {
    setup_claude_code_env
    mock_claude "There's an issue with the selected model (bogus)." 1

    local output
    output=$(_zsh_ai_query_claude_code "list files")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Claude Code Error:"
    assert_contains "$output" "issue with the selected model"

    teardown_claude_code_env
}

test_handles_silent_cli_failure() {
    setup_claude_code_env
    mock_claude "" 1

    local output
    output=$(_zsh_ai_query_claude_code "list files")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Claude Code CLI failed"

    teardown_claude_code_env
}

test_handles_empty_response() {
    setup_claude_code_env
    mock_claude "" 0

    local output
    output=$(_zsh_ai_query_claude_code "list files")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Empty response from Claude Code"

    teardown_claude_code_env
}

test_handles_fences_only_response() {
    setup_claude_code_env
    mock_claude '```
```' 0

    local output
    output=$(_zsh_ai_query_claude_code "list files")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Unable to parse Claude Code response"

    teardown_claude_code_env
}

test_runs_in_safe_mode_by_default() {
    setup_claude_code_env
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    # Safe mode keeps the cwd's CLAUDE.md, hooks and plugins out of the request
    assert_contains "$(claude_args)" "<ARG>--safe-mode"

    teardown_claude_code_env
}

test_safe_mode_can_be_disabled() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_SAFE_MODE="false"
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    assert_not_contains "$(claude_args)" "<ARG>--safe-mode"

    teardown_claude_code_env
}

test_disables_tools_and_session_persistence() {
    setup_claude_code_env
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    local args="$(claude_args)"
    assert_contains "$args" "<ARG>-p"
    assert_contains "$args" "<ARG>--tools<ARG><ARG>"
    assert_contains "$args" "<ARG>--permission-prompts<ARG>none"
    assert_contains "$args" "<ARG>--no-session-persistence"
    assert_contains "$args" "<ARG>--strict-mcp-config"
    assert_contains "$args" "<ARG>--disable-slash-commands"
    assert_contains "$args" "<ARG>--output-format<ARG>text"
    assert_contains "$args" "<ARG>--input-format<ARG>text"

    teardown_claude_code_env
}

test_uses_configured_model() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_MODEL="sonnet"
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    assert_contains "$(claude_args)" "<ARG>--model<ARG>sonnet"

    teardown_claude_code_env
}

test_empty_model_falls_back_to_claude_code_default() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_MODEL=""
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    assert_not_contains "$(claude_args)" "<ARG>--model"

    teardown_claude_code_env
}

test_appends_extra_args() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_ARGS="--settings /tmp/my settings.json"
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    local args="$(claude_args)"
    assert_contains "$args" "<ARG>--settings"
    assert_contains "$args" "<ARG>/tmp/my"

    teardown_claude_code_env
}

test_extra_args_respect_quotes() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_ARGS='--append-system-prompt "prefer rg"'
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    assert_contains "$(claude_args)" "<ARG>--append-system-prompt<ARG>prefer rg"

    teardown_claude_code_env
}

test_passes_system_prompt_with_context() {
    setup_claude_code_env
    mock_claude "ls" 0

    _zsh_ai_query_claude_code "list files" >/dev/null

    local args="$(claude_args)"
    assert_contains "$args" "<ARG>--system-prompt"
    assert_contains "$args" "zsh command generator"
    assert_contains "$args" "Test shell context"
    # The CLI is conversational by default, so the single-line rule is restated
    assert_contains "$args" "No preamble, no reasoning, no markdown code fences."

    teardown_claude_code_env
}

test_honours_prompt_extension() {
    setup_claude_code_env
    export ZSH_AI_PROMPT_EXTEND="Always prefer ripgrep."
    mock_claude "rg foo" 0

    _zsh_ai_query_claude_code "search for foo" >/dev/null

    assert_contains "$(claude_args)" "Always prefer ripgrep."

    unset ZSH_AI_PROMPT_EXTEND
    teardown_claude_code_env
}

test_uses_custom_binary_path() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_BIN="my-claude"
    mock_claude "ls" 0
    # mock_claude defines `claude`; alias the custom name to the same recording
    functions[my-claude]=$functions[claude]

    local output
    output=$(_zsh_ai_query_claude_code "list files")

    assert_equals "$output" "ls"

    unfunction my-claude 2>/dev/null
    teardown_claude_code_env
}

test_check_passes_when_cli_is_installed() {
    setup_claude_code_env
    mock_claude "ls" 0

    _zsh_ai_check_claude_code >/dev/null 2>&1
    assert_equals "$?" "0"

    teardown_claude_code_env
}

test_check_reports_missing_cli() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_BIN="definitely-not-a-real-binary-zsh-ai"

    local output
    output=$(_zsh_ai_check_claude_code 2>&1)
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "not found in PATH"
    assert_contains "$output" "ZSH_AI_CLAUDE_CODE_BIN"

    teardown_claude_code_env
}

test_query_router_uses_claude_code_provider() {
    setup_claude_code_env
    mock_claude "ls -la" 0

    local output
    output=$(_zsh_ai_query "list all files")
    local result=$?

    assert_equals "$result" "0"
    assert_equals "$output" "ls -la"

    teardown_claude_code_env
}

test_query_router_reports_missing_cli() {
    setup_claude_code_env
    export ZSH_AI_CLAUDE_CODE_BIN="definitely-not-a-real-binary-zsh-ai"

    local output
    output=$(_zsh_ai_query "list all files" 2>&1)
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "not found in PATH"

    teardown_claude_code_env
}

# Run tests
echo "Running claude-code provider tests..."
run_test "Successful CLI call" test_successful_cli_call
run_test "Sends query on stdin" test_sends_query_on_stdin
run_test "Query starting with dash is not a flag" test_query_starting_with_dash_is_not_a_flag
run_test "Strips markdown code fences" test_strips_markdown_code_fences
run_test "Strips trailing whitespace and blank lines" test_strips_trailing_whitespace_and_blank_lines
run_test "Handles CLI failure with message" test_handles_cli_failure_with_message
run_test "Handles silent CLI failure" test_handles_silent_cli_failure
run_test "Handles empty response" test_handles_empty_response
run_test "Handles fences-only response" test_handles_fences_only_response
run_test "Runs in safe mode by default" test_runs_in_safe_mode_by_default
run_test "Safe mode can be disabled" test_safe_mode_can_be_disabled
run_test "Disables tools and session persistence" test_disables_tools_and_session_persistence
run_test "Uses configured model" test_uses_configured_model
run_test "Empty model falls back to Claude Code default" test_empty_model_falls_back_to_claude_code_default
run_test "Appends extra args" test_appends_extra_args
run_test "Extra args respect quotes" test_extra_args_respect_quotes
run_test "Passes system prompt with context" test_passes_system_prompt_with_context
run_test "Honours prompt extension" test_honours_prompt_extension
run_test "Uses custom binary path" test_uses_custom_binary_path
run_test "Check passes when CLI is installed" test_check_passes_when_cli_is_installed
run_test "Check reports missing CLI" test_check_reports_missing_cli
run_test "Query router uses claude-code provider" test_query_router_uses_claude_code_provider
run_test "Query router reports missing CLI" test_query_router_reports_missing_cli
finish_tests
