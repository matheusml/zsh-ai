#!/usr/bin/env zsh

# Tests for the T3 Code provider
source "${0:A:h}/../test_helper.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/providers/t3.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"

# Fake CLIs are real executables because the provider runs them through env.
# Each one logs its arguments and selected env vars, then prints
# $FAKE_OUTPUT (or writes it to codex's -o file), and exits with $FAKE_EXIT.
make_fake_cli() {
    local name="$1"
    cat > "$T3_TEST_BIN/$name" <<'EOF'
#!/bin/sh
log="$T3_TEST_LOG"
printf '%s\n' "--- $(basename "$0")" >> "$log"
printf 'CLAUDE_CONFIG_DIR=%s\n' "$CLAUDE_CONFIG_DIR" >> "$log"
printf 'CODEX_HOME=%s\n' "$CODEX_HOME" >> "$log"
printf 'PWD=%s\n' "$PWD" >> "$log"
out=""
prev=""
for arg in "$@"; do
    printf 'ARG=%s\n' "$arg" >> "$log"
    [ "$prev" = "-o" ] && out="$arg"
    prev="$arg"
done
[ -n "$FAKE_STDERR" ] && printf '%s\n' "$FAKE_STDERR" >&2
if [ -n "$out" ]; then
    printf '%s' "$FAKE_OUTPUT" > "$out"
else
    printf '%s' "$FAKE_OUTPUT"
fi
exit "${FAKE_EXIT:-0}"
EOF
    chmod +x "$T3_TEST_BIN/$name"
}

setup_t3_test() {
    setup_test_env
    export ZSH_AI_PROVIDER="t3"
    export ZSH_AI_T3_PROVIDER="claudeAgent"
    export ZSH_AI_T3_MODEL=""
    T3_TEST_DIR=$(mktemp -d)
    T3_TEST_BIN="$T3_TEST_DIR/bin"
    mkdir -p "$T3_TEST_BIN"
    export T3_TEST_LOG="$T3_TEST_DIR/log"
    export ZSH_AI_T3_SETTINGS="$T3_TEST_DIR/settings.json"
    export FAKE_OUTPUT="ls -la"
    export FAKE_EXIT=0
    export FAKE_STDERR=""
    unset CLAUDE_CONFIG_DIR CODEX_HOME
    T3_TEST_OLD_PATH="$PATH"
    export PATH="$T3_TEST_BIN:$PATH"
    make_fake_cli claude
    make_fake_cli codex
    make_fake_cli gemini
}

teardown_t3_test() {
    export PATH="$T3_TEST_OLD_PATH"
    rm -rf "$T3_TEST_DIR"
    teardown_test_env
    unset ZSH_AI_T3_PROVIDER ZSH_AI_T3_MODEL ZSH_AI_T3_SETTINGS
    unset T3_TEST_DIR T3_TEST_BIN T3_TEST_LOG T3_TEST_OLD_PATH FAKE_OUTPUT FAKE_EXIT FAKE_STDERR
}

write_settings() {
    print -r -- "$1" > "$ZSH_AI_T3_SETTINGS"
}

test_claude_runs_one_off_without_tools() {
    setup_t3_test

    local result
    result=$(_zsh_ai_query_t3 "list files")
    assert_equals "$?" "0"
    assert_equals "$result" "ls -la"
    local log=$(cat "$T3_TEST_LOG")
    assert_contains "$log" "--- claude"
    assert_contains "$log" $'ARG=-p\n'
    assert_contains "$log" $'ARG=--tools\nARG=\n'
    assert_contains "$log" "ARG=--no-session-persistence"
    assert_contains "$log" $'ARG=--model\nARG=claude-haiku-5-5'
    assert_contains "$log" "zsh command generator"
    assert_contains "$log" "ARG=list files"

    teardown_t3_test
}

test_uses_t3_binary_and_home_for_claude() {
    setup_t3_test
    make_fake_cli my-claude
    write_settings '{"providerInstances":{"claudeAgent":{"driver":"claudeAgent","enabled":true,"config":{"binaryPath":"'"$T3_TEST_BIN"'/my-claude","homePath":"~/.claude-work"}}}}'

    _zsh_ai_query_t3 "list files" >/dev/null
    local log=$(cat "$T3_TEST_LOG")
    assert_contains "$log" "--- my-claude"
    assert_contains "$log" "CLAUDE_CONFIG_DIR=$HOME/.claude-work"

    teardown_t3_test
}

test_codex_runs_ephemeral_read_only() {
    setup_t3_test
    export ZSH_AI_T3_PROVIDER="codex"
    write_settings '{"providerInstances":{"codex":{"driver":"codex","config":{"homePath":"/tmp/codex-home"}}}}'
    FAKE_OUTPUT="git status"

    local result
    result=$(_zsh_ai_query_t3 "show git status")
    assert_equals "$?" "0"
    assert_equals "$result" "git status"
    local log=$(cat "$T3_TEST_LOG")
    assert_contains "$log" "--- codex"
    assert_contains "$log" "CODEX_HOME=/tmp/codex-home"
    assert_contains "$log" "ARG=--ephemeral"
    assert_contains "$log" $'ARG=--sandbox\nARG=read-only'
    assert_contains "$log" $'ARG=-m\nARG=gpt-6-luna'
    assert_contains "$log" "User request: show git status"

    teardown_t3_test
}

test_gemini_runs_headless() {
    setup_t3_test
    export ZSH_AI_T3_PROVIDER="gemini"
    FAKE_OUTPUT="pwd"

    local result
    result=$(_zsh_ai_query_t3 "where am I")
    assert_equals "$?" "0"
    assert_equals "$result" "pwd"
    local log=$(cat "$T3_TEST_LOG")
    assert_contains "$log" "--- gemini"
    assert_contains "$log" $'ARG=-m\nARG=gemini-3.8-flash'
    assert_contains "$log" "User request: where am I"
    assert_not_contains "$log" "PWD=$PWD"$'\n'

    teardown_t3_test
}

test_maps_provider_aliases() {
    local alias cli
    for alias cli in anthropic claude claude claude openai codex codex codex google gemini; do
        setup_t3_test
        export ZSH_AI_T3_PROVIDER="$alias"
        _zsh_ai_query_t3 "where am I" >/dev/null
        assert_contains "$(cat "$T3_TEST_LOG")" "--- $cli"
        teardown_t3_test
    done
}

test_uses_custom_instance_driver_from_settings() {
    setup_t3_test
    export ZSH_AI_T3_PROVIDER="codexWork"
    write_settings '{"providerInstances":{"codexWork":{"driver":"codex","config":{"homePath":"~/.codex-t3/work"}}}}'

    _zsh_ai_query_t3 "where am I" >/dev/null
    local log=$(cat "$T3_TEST_LOG")
    assert_contains "$log" "--- codex"
    assert_contains "$log" "CODEX_HOME=$HOME/.codex-t3/work"
    assert_contains "$log" $'ARG=-m\nARG=gpt-6-luna'

    teardown_t3_test
}

test_uses_configured_model() {
    setup_t3_test
    export ZSH_AI_T3_MODEL="claude-sonnet-5-5"

    _zsh_ai_query_t3 "where am I" >/dev/null
    assert_contains "$(cat "$T3_TEST_LOG")" $'ARG=--model\nARG=claude-sonnet-5-5'

    teardown_t3_test
}

test_rejects_disabled_instance() {
    setup_t3_test
    write_settings '{"providerInstances":{"claudeAgent":{"driver":"claudeAgent","enabled":false}}}'

    local result
    result=$(_zsh_ai_query_t3 "where am I")
    assert_equals "$?" "1"
    assert_contains "$result" "disabled"
    [[ ! -e "$T3_TEST_LOG" ]] || { echo "CLI should not run"; TEST_FAILED=1; }

    teardown_t3_test
}

test_rejects_unsupported_driver() {
    setup_t3_test
    export ZSH_AI_T3_PROVIDER="cursor"
    write_settings '{"providerInstances":{"cursor":{"driver":"cursor"}}}'

    local result
    result=$(_zsh_ai_query_t3 "where am I")
    assert_equals "$?" "1"
    assert_contains "$result" "not supported"

    teardown_t3_test
}

test_reports_missing_binary() {
    setup_t3_test
    write_settings '{"providerInstances":{"claudeAgent":{"driver":"claudeAgent","config":{"binaryPath":"/nonexistent/claude"}}}}'

    local result
    result=$(_zsh_ai_query_t3 "where am I")
    assert_equals "$?" "1"
    assert_contains "$result" "'/nonexistent/claude' not found"

    teardown_t3_test
}

test_ignores_invalid_settings() {
    setup_t3_test
    write_settings 'not json'

    local result
    result=$(_zsh_ai_query_t3 "list files")
    assert_equals "$?" "0"
    assert_equals "$result" "ls -la"

    teardown_t3_test
}

test_reports_cli_failure_with_stderr() {
    setup_t3_test
    FAKE_OUTPUT=""
    FAKE_EXIT=1
    FAKE_STDERR=$'some log\nNot logged in. Run claude auth login.'

    local result
    result=$(_zsh_ai_query_t3 "list files")
    assert_equals "$?" "1"
    assert_equals "$result" "Error: claude failed (exit 1). Not logged in. Run claude auth login."

    teardown_t3_test
}

test_reports_empty_reply() {
    local output result
    for output in "" "   "; do
        setup_t3_test
        FAKE_OUTPUT="$output"
        result=$(_zsh_ai_query_t3 "list files")
        assert_equals "$?" "1"
        assert_contains "$result" "empty reply"
        teardown_t3_test
    done
}

test_cleans_reply() {
    local output result
    for output in $'```zsh\nls -la\n```' '`ls -la`' $'  ls -la \n'; do
        setup_t3_test
        FAKE_OUTPUT="$output"
        result=$(_zsh_ai_query_t3 "list files")
        assert_equals "$?" "0"
        assert_equals "$result" "ls -la"
        teardown_t3_test
    done
}

test_keeps_unicode_reply() {
    setup_t3_test
    FAKE_OUTPUT="echo 'café'"

    local result
    result=$(_zsh_ai_query_t3 "print café")
    assert_equals "$result" "echo 'café'"

    teardown_t3_test
}

test_works_with_noclobber() {
    local cli result
    for cli in claudeAgent codex gemini; do
        setup_t3_test
        export ZSH_AI_T3_PROVIDER="$cli"
        result=$(setopt noclobber; _zsh_ai_query_t3 "list files" 2>&1)
        assert_equals "$?" "0"
        assert_equals "$result" "ls -la"
        teardown_t3_test
    done
}

echo "Running T3 provider tests..."
run_test "Claude runs one-off without tools" test_claude_runs_one_off_without_tools
run_test "Uses T3 binary and home for Claude" test_uses_t3_binary_and_home_for_claude
run_test "Codex runs ephemeral and read-only" test_codex_runs_ephemeral_read_only
run_test "Gemini runs headless" test_gemini_runs_headless
run_test "Maps provider aliases" test_maps_provider_aliases
run_test "Uses custom instance driver from settings" test_uses_custom_instance_driver_from_settings
run_test "Uses configured model" test_uses_configured_model
run_test "Rejects disabled instance" test_rejects_disabled_instance
run_test "Rejects unsupported driver" test_rejects_unsupported_driver
run_test "Reports missing binary" test_reports_missing_binary
run_test "Ignores invalid settings" test_ignores_invalid_settings
run_test "Reports CLI failure with stderr" test_reports_cli_failure_with_stderr
run_test "Reports empty reply" test_reports_empty_reply
run_test "Cleans reply" test_cleans_reply
run_test "Keeps unicode reply" test_keeps_unicode_reply
run_test "Works with noclobber set" test_works_with_noclobber
finish_tests
