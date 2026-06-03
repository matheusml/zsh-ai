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
finish_tests
