#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

source "$PLUGIN_DIR/lib/config.zsh"

expect_query() {
    BUFFER="$1"
    ZSH_AI_TRIGGER="$2"
    local out
    out=$(_zsh_ai_prompt_query)
    local rc=$?
    assert_equals "$rc" "0"
    assert_equals "$out" "$3"
}

expect_no_query() {
    BUFFER="$1"
    ZSH_AI_TRIGGER="$2"
    if _zsh_ai_prompt_query >/dev/null; then
        echo "Expected '$1' not to be an AI prompt"
        TEST_FAILED=1
        return 1
    fi
}

test_default_trigger_with_space() {
    expect_query "# list files" "# " "list files"
}

test_default_trigger_without_space() {
    expect_query "#list files" "# " "list files"
    expect_query "#   list files" "# " "list files"
}

test_default_trigger_needs_text() {
    expect_no_query "#" "# "
    expect_no_query "# " "# "
    expect_no_query "#   " "# "
}

test_plain_command_is_not_prompt() {
    expect_no_query "ls -la" "# "
}

test_custom_trigger_only() {
    expect_query ",,list files" ",," "list files"
    expect_no_query "#list files" ",,"
    expect_no_query "# list files" ",,"
}

echo "Running trigger tests..."
run_test "Default trigger with space" test_default_trigger_with_space
run_test "Default trigger without space" test_default_trigger_without_space
run_test "Default trigger needs text after it" test_default_trigger_needs_text
run_test "Plain command is not a prompt" test_plain_command_is_not_prompt
run_test "Custom trigger matches only itself" test_custom_trigger_only
finish_tests
