#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/history.zsh"

# Use an isolated data directory for each test
with_history_dir() {
    local test_func="$1"
    local data_dir=$(mktemp -d)
    local saved_xdg="$XDG_DATA_HOME"
    export XDG_DATA_HOME="$data_dir"
    ZSH_AI_TRIGGER="# "
    BUFFER=""
    CURSOR=0
    _zsh_ai_history_reset
    "$test_func"
    local result=$?
    export XDG_DATA_HOME="$saved_xdg"
    rm -rf "$data_dir"
    return $result
}

test_round_trip_keeps_prompts() {
    _zsh_ai_history_save "show current date"
    _zsh_ai_history_save 'multi line "quoted" $HOME'
    local loaded=$(_zsh_ai_history_load)
    assert_contains "$loaded" "show current date"
    assert_contains "$loaded" 'multi line "quoted" $HOME'
}

test_prompts_are_encrypted_on_disk() {
    _zsh_ai_history_save "secret token for prod"
    local stored=$(<"$XDG_DATA_HOME/zsh-ai/history.enc")
    assert_not_contains "$stored" "secret token"
    assert_equals "$(stat -c %a "$XDG_DATA_HOME/zsh-ai/history.key")" "600"
    assert_equals "$(stat -c %a "$XDG_DATA_HOME/zsh-ai")" "700"
}

test_disabled_history_stores_nothing() {
    ZSH_AI_HISTORY="off"
    _zsh_ai_history_save "should not be stored"
    _zsh_ai_history_enabled
    assert_equals "$?" "1"
    ZSH_AI_HISTORY="true"
    [[ ! -e "$XDG_DATA_HOME/zsh-ai/history.enc" ]]
}

test_history_capped_to_max() {
    ZSH_AI_HISTORY_MAX=2
    _zsh_ai_history_save "first"
    _zsh_ai_history_save "second"
    _zsh_ai_history_save "third"
    local loaded=$(_zsh_ai_history_load)
    assert_not_contains "$loaded" "first"
    assert_contains "$loaded" "second"
    assert_contains "$loaded" "third"
    ZSH_AI_HISTORY_MAX=500
}

test_up_down_cycles_and_restores_draft() {
    _zsh_ai_history_save "one"
    _zsh_ai_history_save "two"
    BUFFER="# draft"
    _zsh_ai_history_step -1
    assert_equals "$BUFFER" "# two"
    _zsh_ai_history_step -1
    assert_equals "$BUFFER" "# one"
    _zsh_ai_history_step -1
    assert_equals "$BUFFER" "# one"
    _zsh_ai_history_step 1
    assert_equals "$BUFFER" "# two"
    _zsh_ai_history_step 1
    assert_equals "$BUFFER" "# draft"
}

test_up_ignores_plain_shell_buffer() {
    _zsh_ai_history_save "one"
    BUFFER="ls -la"
    _zsh_ai_history_step -1
    assert_not_equals_status "$?" "0"
    assert_equals "$BUFFER" "ls -la"
}

test_bare_hash_starts_browsing() {
    _zsh_ai_history_save "saved prompt"
    BUFFER="#"
    _zsh_ai_history_step -1
    assert_equals "$BUFFER" "# saved prompt"
}

test_no_history_falls_back() {
    BUFFER="# draft"
    _zsh_ai_history_step -1
    assert_not_equals_status "$?" "0"
    assert_equals "$BUFFER" "# draft"
}

assert_not_equals_status() {
    if [[ "$1" == "$2" ]]; then
        echo "Expected status not to be $2"
        TEST_FAILED=1
        return 1
    fi
}

echo "Running history tests..."
run_test "History round trip keeps prompts" with_history_dir test_round_trip_keeps_prompts
run_test "Prompts are encrypted on disk with private key" with_history_dir test_prompts_are_encrypted_on_disk
run_test "Disabled history stores nothing" with_history_dir test_disabled_history_stores_nothing
run_test "History is capped to max entries" with_history_dir test_history_capped_to_max
run_test "Up/down cycles and restores draft" with_history_dir test_up_down_cycles_and_restores_draft
run_test "Up ignores plain shell buffer" with_history_dir test_up_ignores_plain_shell_buffer
run_test "Bare hash starts browsing" with_history_dir test_bare_hash_starts_browsing
run_test "No history falls back to shell history" with_history_dir test_no_history_falls_back
finish_tests
