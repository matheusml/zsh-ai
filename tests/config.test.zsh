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

# Config file tests
test_config_file_loads_provider() {
    setup_test_env
    local test_dir=$(create_test_dir)
    local config_dir="$test_dir/zsh-ai"
    mkdir -p "$config_dir"
    echo 'ZSH_AI_PROVIDER=ollama' > "$config_dir/config"

    # Use the test dir as XDG_CONFIG_HOME
    unset ZSH_AI_PROVIDER
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    assert_equals "$ZSH_AI_PROVIDER" "ollama"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

test_config_file_loads_model() {
    setup_test_env
    local test_dir=$(create_test_dir)
    local config_dir="$test_dir/zsh-ai"
    mkdir -p "$config_dir"
    echo 'ZSH_AI_OLLAMA_MODEL=codellama' > "$config_dir/config"

    unset ZSH_AI_OLLAMA_MODEL
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    assert_equals "$ZSH_AI_OLLAMA_MODEL" "codellama"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

test_env_var_overrides_config_file() {
    setup_test_env
    local test_dir=$(create_test_dir)
    local config_dir="$test_dir/zsh-ai"
    mkdir -p "$config_dir"
    echo 'ZSH_AI_PROVIDER=ollama' > "$config_dir/config"

    # Set env var BEFORE sourcing config
    export ZSH_AI_PROVIDER="anthropic"
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    # Env var should win over config file
    assert_equals "$ZSH_AI_PROVIDER" "anthropic"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

test_works_without_config_file() {
    setup_test_env
    local test_dir=$(create_test_dir)
    # Don't create a config file

    unset ZSH_AI_PROVIDER
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    # Should fall back to defaults
    assert_equals "$ZSH_AI_PROVIDER" "anthropic"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

test_xdg_config_home_respected() {
    setup_test_env
    local test_dir=$(create_test_dir)
    local config_dir="$test_dir/zsh-ai"
    mkdir -p "$config_dir"
    echo 'ZSH_AI_PROVIDER=gemini' > "$config_dir/config"

    unset ZSH_AI_PROVIDER
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    assert_equals "$ZSH_AI_PROVIDER" "gemini"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

test_config_file_prompt_extend() {
    setup_test_env
    local test_dir=$(create_test_dir)
    local config_dir="$test_dir/zsh-ai"
    mkdir -p "$config_dir"
    echo 'ZSH_AI_PROMPT_EXTEND="Always be concise"' > "$config_dir/config"

    unset ZSH_AI_PROMPT_EXTEND
    export XDG_CONFIG_HOME="$test_dir"
    source "$PLUGIN_DIR/lib/config.zsh"

    assert_equals "$ZSH_AI_PROMPT_EXTEND" "Always be concise"

    cleanup_test_dir "$test_dir"
    unset XDG_CONFIG_HOME
    teardown_test_env
}

# Run tests
echo "Running config tests..."
test_default_provider && echo "✓ Default provider is anthropic"
test_default_ollama_model && echo "✓ Default Ollama model is llama3.2"
test_default_ollama_url && echo "✓ Default Ollama URL is localhost:11434"
test_validates_anthropic_provider && echo "✓ Validates anthropic provider"
test_validates_ollama_provider && echo "✓ Validates ollama provider"
test_rejects_invalid_provider && echo "✓ Rejects invalid provider"
test_validates_gemini_provider && echo "✓ Validates gemini provider"
test_validates_openai_provider && echo "✓ Validates openai provider"

# Config file tests
echo ""
echo "Running config file tests..."
test_config_file_loads_provider && echo "✓ Config file loads provider"
test_config_file_loads_model && echo "✓ Config file loads model"
test_env_var_overrides_config_file && echo "✓ Environment variable overrides config file"
test_works_without_config_file && echo "✓ Works without config file"
test_xdg_config_home_respected && echo "✓ XDG_CONFIG_HOME is respected"
test_config_file_prompt_extend && echo "✓ Config file loads prompt extend"