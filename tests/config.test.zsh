#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load the config module
source "$PLUGIN_DIR/lib/config.zsh"

# Test functions
test_default_provider() {
    setup_test_env
    unset ZSH_AI_PROVIDER
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_PROVIDER" "anthropic"
    teardown_test_env
}

test_default_ollama_model() {
    setup_test_env
    unset ZSH_AI_OLLAMA_MODEL
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_OLLAMA_MODEL" "llama3.2"
    teardown_test_env
}

test_default_ollama_url() {
    setup_test_env
    unset ZSH_AI_OLLAMA_URL
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_OLLAMA_URL" "http://localhost:11434"
    teardown_test_env
}

test_validates_anthropic_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_validates_ollama_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_rejects_invalid_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="invalid"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "1"
    teardown_test_env
}

test_validates_gemini_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="gemini"
    export GEMINI_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_validates_openai_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="openai"
    export OPENAI_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_default_openai_auth_is_api_key() {
    setup_test_env
    unset ZSH_AI_OPENAI_AUTH
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_OPENAI_AUTH" "api_key"
    teardown_test_env
}

test_default_codex_config() {
    setup_test_env
    unset ZSH_AI_CODEX_ISSUER
    unset ZSH_AI_CODEX_URL
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_CODEX_ISSUER" "https://auth.openai.com"
    assert_equals "$ZSH_AI_CODEX_URL" "https://chatgpt.com/backend-api/codex/responses"
    teardown_test_env
}

test_openai_codex_auth_does_not_require_api_key() {
    setup_test_env
    unset OPENAI_API_KEY
    unset ZSH_AI_OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_rejects_invalid_openai_auth() {
    setup_test_env
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_AUTH="invalid"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "1"
    teardown_test_env
}

test_comment_hook_enabled_by_default() {
    setup_test_env
    unset ZSH_AI_COMMENT_HOOK
    source "$PLUGIN_DIR/lib/config.zsh"
    _zsh_ai_comment_hook_enabled
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_comment_hook_can_be_disabled() {
    setup_test_env
    local value
    for value in false off no 0 disabled FALSE Off; do
        export ZSH_AI_COMMENT_HOOK="$value"
        _zsh_ai_comment_hook_enabled
        assert_equals "$?" "1"
    done
    unset ZSH_AI_COMMENT_HOOK
    teardown_test_env
}

test_default_trigger_is_hash() {
    setup_test_env
    unset ZSH_AI_TRIGGER
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_TRIGGER" "# "
    teardown_test_env
}

# Run tests
echo "Running config tests..."
run_test "Default provider is anthropic" test_default_provider
run_test "Default Ollama model is llama3.2" test_default_ollama_model
run_test "Default Ollama URL is localhost:11434" test_default_ollama_url
run_test "Validates anthropic provider" test_validates_anthropic_provider
run_test "Validates ollama provider" test_validates_ollama_provider
run_test "Rejects invalid provider" test_rejects_invalid_provider
run_test "Validates gemini provider" test_validates_gemini_provider
run_test "Validates openai provider" test_validates_openai_provider
run_test "Default OpenAI auth is api_key" test_default_openai_auth_is_api_key
run_test "Default Codex config is set" test_default_codex_config
run_test "OpenAI Codex auth does not require API key" test_openai_codex_auth_does_not_require_api_key
run_test "Rejects invalid OpenAI auth mode" test_rejects_invalid_openai_auth
run_test "Comment hook enabled by default" test_comment_hook_enabled_by_default
run_test "Comment hook can be disabled" test_comment_hook_can_be_disabled
run_test "Default trigger is '# '" test_default_trigger_is_hash
finish_tests
