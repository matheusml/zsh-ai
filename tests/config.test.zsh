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

test_default_apfel_settings() {
    setup_test_env
    unset ZSH_AI_APFEL_URL ZSH_AI_APFEL_MAX_TOKENS
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_APFEL_URL" "http://127.0.0.1:11434/v1/chat/completions"
    assert_equals "$ZSH_AI_APFEL_MAX_TOKENS" "256"
    teardown_test_env
}

test_validates_apfel_without_api_key() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"
    unset ZSH_AI_APFEL_API_KEY OPENAI_API_KEY ZSH_AI_OPENAI_API_KEY
    _zsh_ai_validate_config >/dev/null 2>&1
    assert_equals "$?" "0"
    teardown_test_env
}

test_rejects_invalid_apfel_token_limit() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"
    export ZSH_AI_APFEL_MAX_TOKENS="0"
    _zsh_ai_validate_config >/dev/null 2>&1
    assert_equals "$?" "1"
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

test_validates_custom_provider() {
      local had_custom_function=$+functions[_zsh_ai_query_custom]
      local saved_custom_function="${functions[_zsh_ai_query_custom]-}"

      {
          setup_test_env
          export ZSH_AI_PROVIDER="custom"

          _zsh_ai_query_custom() {
              return 0
          }

          _zsh_ai_validate_config >/dev/null 2>&1
          assert_equals "$?" "0"
      } always {
          teardown_test_env

          if (( had_custom_function )); then
              functions[_zsh_ai_query_custom]="$saved_custom_function"
          else
              unfunction _zsh_ai_query_custom 2>/dev/null
          fi
      }
}

test_rejects_missing_custom_provider_function() {
      local had_custom_function=$+functions[_zsh_ai_query_custom]
      local saved_custom_function="${functions[_zsh_ai_query_custom]-}"

      {
          setup_test_env
          export ZSH_AI_PROVIDER="custom"
          unfunction _zsh_ai_query_custom 2>/dev/null

          _zsh_ai_validate_config >/dev/null 2>&1
          assert_equals "$?" "1"
      } always {
          teardown_test_env

          if (( had_custom_function )); then
              functions[_zsh_ai_query_custom]="$saved_custom_function"
          else
              unfunction _zsh_ai_query_custom 2>/dev/null
          fi
      }
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
run_test "Default Apfel settings" test_default_apfel_settings
run_test "Validates Apfel without an API key" test_validates_apfel_without_api_key
run_test "Rejects invalid Apfel token limit" test_rejects_invalid_apfel_token_limit
run_test "Validates ollama provider" test_validates_ollama_provider
run_test "Rejects invalid provider" test_rejects_invalid_provider
run_test "Validates gemini provider" test_validates_gemini_provider
run_test "Validates openai provider" test_validates_openai_provider
run_test "Validates custom provider" test_validates_custom_provider
run_test "Rejects missing custom provider function" test_rejects_missing_custom_provider_function
run_test "Comment hook enabled by default" test_comment_hook_enabled_by_default
run_test "Comment hook can be disabled" test_comment_hook_can_be_disabled
run_test "Default trigger is '# '" test_default_trigger_is_hash
finish_tests
