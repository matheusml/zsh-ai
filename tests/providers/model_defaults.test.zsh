#!/usr/bin/env zsh

# Regression coverage for model upgrades: request compatibility and prompt review.
source "${0:A:h:h}/test_helper.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/providers/gemini.zsh"
source "$PLUGIN_DIR/lib/providers/openai.zsh"
source "$PLUGIN_DIR/lib/providers/qwen.zsh"
source "$PLUGIN_DIR/lib/widget.zsh"

_zsh_ai_build_context() {
    printf '%s' 'Test shell context'
}

# Run with isolated defaults and capture real provider requests without network IO.
with_defaults() {
    local parser="$1"
    shift
    setup_test_env
    local ZSH_AI_PROVIDER=""
    local ZSH_AI_GEMINI_MODEL="" ZSH_AI_OPENAI_MODEL="" ZSH_AI_QWEN_MODEL=""
    local ZSH_AI_OPENAI_URL="" ZSH_AI_QWEN_URL=""
    local ZSH_AI_OPENAI_THINKING="" ZSH_AI_OPENAI_REASONING_EFFORT=""
    local ZSH_AI_OPENAI_MAX_TOKENS="" ZSH_AI_OPENAI_API_KEY=""
    local GEMINI_API_KEY="test-key" OPENAI_API_KEY="test-key" QWEN_API_KEY="test-key"
    source "$PLUGIN_DIR/lib/config.zsh"

    local request_dir=$(mktemp -d)
    local mock_response='{"choices":[{"message":{"content":"git status"}}]}'
    local mock_exit_code=0
    if [[ "$parser" == "no-jq" ]]; then
        mock_jq false
    elif ! command -v jq >/dev/null 2>&1; then
        mock_jq true
    fi

    curl() {
        local arg previous=""
        for arg in "$@"; do
            if [[ "$previous" == "--data" ]]; then
                printf '%s' "$arg" > "$request_dir/payload"
            elif [[ "$arg" == https://* || "$arg" == http://* ]]; then
                printf '%s' "$arg" > "$request_dir/url"
            fi
            previous="$arg"
        done
        printf '%s' "$mock_response"
        return "$mock_exit_code"
    }

    "$@"
    local result=$TEST_FAILED
    unfunction zle print 2>/dev/null
    teardown_test_env
    rm -rf "$request_dir"
    return "$result"
}

select_provider() {
    ZSH_AI_PROVIDER="$1"
    if [[ "$1" == "gemini" ]]; then
        mock_response='{"candidates":[{"content":{"parts":[{"text":"git status"}]}}]}'
    fi
}

test_default_models() {
    assert_equals "$ZSH_AI_GEMINI_MODEL" "gemini-3.5-flash-lite"
    assert_equals "$ZSH_AI_OPENAI_MODEL" "gpt-5.6-luna"
    assert_equals "$ZSH_AI_QWEN_MODEL" "qwen3.8-flash"
}

test_explicit_models_survive_config_reload() {
    ZSH_AI_GEMINI_MODEL="gemini-2.5-flash"
    ZSH_AI_OPENAI_MODEL="gpt-4o-mini"
    ZSH_AI_QWEN_MODEL="qwen-flash"
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_GEMINI_MODEL" "gemini-2.5-flash"
    assert_equals "$ZSH_AI_OPENAI_MODEL" "gpt-4o-mini"
    assert_equals "$ZSH_AI_QWEN_MODEL" "qwen-flash"
}

test_openai_default_request() {
    _zsh_ai_query_openai 'show "git" status' >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"model": "gpt-5.6-luna"'
    assert_contains "$payload" '"max_completion_tokens": 256'
    assert_contains "$payload" '"reasoning_effort": "none"'
    assert_contains "$payload" 'show \"git\" status'
    assert_not_contains "$payload" '"temperature"'
}

test_openai_explicit_effort() {
    ZSH_AI_OPENAI_REASONING_EFFORT="low"
    _zsh_ai_query_openai "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"reasoning_effort": "low"'
    assert_not_contains "$payload" '"reasoning_effort": "none"'
}

test_openai_custom_endpoint_defaults() {
    ZSH_AI_OPENAI_URL="http://localhost:8080/v1/chat/completions"
    _zsh_ai_query_openai "show git status" >/dev/null
    assert_equals "$(<"$request_dir/url")" "$ZSH_AI_OPENAI_URL"
    assert_not_contains "$(<"$request_dir/payload")" '"reasoning_effort"'
}

test_openai_legacy_model() {
    ZSH_AI_OPENAI_MODEL="gpt-4o-mini"
    _zsh_ai_query_openai "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"model": "gpt-4o-mini"'
    assert_contains "$payload" '"max_tokens": 256'
    assert_contains "$payload" '"temperature": 0.3'
    assert_not_contains "$payload" '"reasoning_effort"'
}

test_qwen_default_request() {
    _zsh_ai_query_qwen "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"model": "qwen3.8-flash"'
    assert_contains "$payload" '"max_tokens": 256'
    assert_contains "$payload" '"reasoning_effort": "none"'
}

test_qwen_legacy_model() {
    ZSH_AI_QWEN_MODEL="qwen-flash"
    _zsh_ai_query_qwen "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"model": "qwen-flash"'
    assert_not_contains "$payload" '"reasoning_effort"'
}

test_gemini_default_request() {
    select_provider gemini
    _zsh_ai_query_gemini "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$(<"$request_dir/url")" '/gemini-3.5-flash-lite:generateContent?'
    assert_contains "$payload" '"thinkingLevel": "MINIMAL"'
    assert_contains "$payload" '"temperature": 1.0'
    assert_contains "$payload" '"maxOutputTokens": 1024'
    assert_not_contains "$payload" '"thinkingBudget"'
}

test_gemini_legacy_model() {
    select_provider gemini
    ZSH_AI_GEMINI_MODEL="gemini-2.5-flash"
    _zsh_ai_query_gemini "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$(<"$request_dir/url")" '/gemini-2.5-flash:generateContent?'
    assert_contains "$payload" '"thinkingBudget": 0'
    assert_contains "$payload" '"temperature": 0.3'
    assert_contains "$payload" '"maxOutputTokens": 256'
    assert_not_contains "$payload" '"thinkingLevel"'
}

test_gemini_low_thinking_model() {
    select_provider gemini
    ZSH_AI_GEMINI_MODEL="$1"
    _zsh_ai_query_gemini "show git status" >/dev/null
    local payload=$(<"$request_dir/payload")
    assert_contains "$payload" '"thinkingLevel": "LOW"'
    assert_not_contains "$payload" 'MINIMAL'
    assert_not_contains "$payload" '"thinkingBudget"'
}

test_response_parsing() {
    select_provider "$1"
    local output
    output=$(_zsh_ai_query "show git status")
    assert_equals "$?" "0"
    assert_equals "$output" "git status"
}

test_api_error() {
    select_provider "$1"
    mock_response='{"error":{"message":"Invalid API key"}}'
    local output
    output=$(_zsh_ai_query "show git status")
    assert_equals "$?" "1"
    assert_contains "$output" 'Error:'
}

test_empty_response() {
    select_provider "$1"
    mock_response='{}'
    local output
    output=$(_zsh_ai_query "show git status")
    assert_equals "$?" "1"
    assert_contains "$output" 'Unable to parse response'
}

test_connection_failure() {
    select_provider "$1"
    mock_exit_code=1
    local output
    output=$(_zsh_ai_query "show git status")
    assert_equals "$?" "1"
    assert_contains "$output" 'Failed to connect'
}

test_commands_wait_for_review() {
    select_provider "$1"
    local accepted=0 queued="" BUFFER="# show git status" CURSOR=0
    zle() {
        [[ "$1" == ".accept-line" ]] && accepted=1
        return 0
    }
    print() {
        if [[ "$1" == "-z" ]]; then
            queued="$2"
        else
            builtin print "$@"
        fi
    }

    _zsh_ai_accept_line >/dev/null
    assert_equals "$BUFFER" "git status"
    assert_equals "$CURSOR" "${#BUFFER}"
    assert_equals "$accepted" "0"
    zsh-ai "show git status" >/dev/null
    assert_equals "$?" "0"
    assert_equals "$queued" "git status"
    assert_equals "$accepted" "0"
}

echo "Running model default migration tests..."
run_test "Current hosted model defaults" with_defaults jq test_default_models
run_test "Explicit models survive config reload" with_defaults jq test_explicit_models_survive_config_reload
run_test "Luna disables reasoning within the command token budget" with_defaults jq test_openai_default_request
run_test "Explicit OpenAI reasoning effort takes priority" with_defaults jq test_openai_explicit_effort
run_test "Custom OpenAI endpoints keep server reasoning defaults" with_defaults jq test_openai_custom_endpoint_defaults
run_test "Legacy OpenAI overrides retain compatible parameters" with_defaults jq test_openai_legacy_model
run_test "Qwen 3.8 disables reasoning for commands" with_defaults jq test_qwen_default_request
run_test "Legacy Qwen overrides omit new reasoning settings" with_defaults jq test_qwen_legacy_model
run_test "Gemini Flash-Lite uses compatible generation settings" with_defaults jq test_gemini_default_request
run_test "Gemini 2.5 overrides retain their generation settings" with_defaults jq test_gemini_legacy_model
run_test "Gemini 3.8 Flash uses supported LOW thinking" with_defaults jq test_gemini_low_thinking_model gemini-3.8-flash
run_test "Gemini 3.1 Pro uses supported LOW thinking" with_defaults jq test_gemini_low_thinking_model gemini-3.1-pro-preview

for provider in gemini openai qwen; do
    for parser in jq no-jq; do
        run_test "$provider response parsing ($parser)" with_defaults "$parser" test_response_parsing "$provider"
        run_test "$provider API errors ($parser)" with_defaults "$parser" test_api_error "$provider"
        run_test "$provider empty responses ($parser)" with_defaults "$parser" test_empty_response "$provider"
        run_test "$provider connection failures ($parser)" with_defaults "$parser" test_connection_failure "$provider"
        run_test "$provider commands wait for review through both entrypoints ($parser)" with_defaults "$parser" test_commands_wait_for_review "$provider"
    done
done
finish_tests
