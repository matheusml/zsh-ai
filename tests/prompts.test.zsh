#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load the prompts module
source "$PLUGIN_DIR/lib/prompts.zsh"

# Test functions

test_default_system_prompt() {
    setup_test_env
    
    # Unset any custom prompt to test default
    unset ZSH_AI_SYSTEM_PROMPT
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that default prompt contains expected content
    assert_contains "$prompt" "You are a zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    assert_contains "$prompt" "Examples:"
}

test_custom_system_prompt_override() {
    setup_test_env
    
    # Set a custom prompt
    export ZSH_AI_SYSTEM_PROMPT="My custom prompt for testing"
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that custom prompt is returned
    assert_equals "$prompt" "My custom prompt for testing"
}

test_empty_custom_prompt_uses_default() {
    setup_test_env
    
    # Set empty custom prompt
    export ZSH_AI_SYSTEM_PROMPT=""
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that default prompt is used when custom is empty
    assert_contains "$prompt" "You are a zsh command generator"
}

test_multiline_custom_prompt() {
    setup_test_env
    
    # Set multiline custom prompt
    export ZSH_AI_SYSTEM_PROMPT="Line 1
Line 2
Line 3"
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that multiline prompt is preserved
    assert_equals "$prompt" "Line 1
Line 2
Line 3"
}

test_special_characters_in_prompt() {
    setup_test_env
    
    # Set prompt with special characters (note: \n is interpreted by zsh)
    export ZSH_AI_SYSTEM_PROMPT='Special chars: $USER "quotes" and tabs'
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that special characters are preserved
    assert_equals "$prompt" 'Special chars: $USER "quotes" and tabs'
}

# Run tests
echo "Running system prompt tests..."
test_default_system_prompt
test_custom_system_prompt_override
test_empty_custom_prompt_uses_default
test_multiline_custom_prompt
test_special_characters_in_prompt