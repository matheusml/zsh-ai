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
    
    # Should NOT contain additional instructions when no custom prompt
    assert_not_contains "$prompt" "ADDITIONAL INSTRUCTIONS"
}

test_custom_prompt_extends_default() {
    setup_test_env
    
    # Set a custom prompt
    export ZSH_AI_SYSTEM_PROMPT="Prefer using ripgrep over grep"
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that BOTH default and custom prompts are present
    assert_contains "$prompt" "You are a zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    assert_contains "$prompt" "ADDITIONAL INSTRUCTIONS:"
    assert_contains "$prompt" "Prefer using ripgrep over grep"
}

test_empty_custom_prompt_uses_default() {
    setup_test_env
    
    # Set empty custom prompt
    export ZSH_AI_SYSTEM_PROMPT=""
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that default prompt is used when custom is empty
    assert_contains "$prompt" "You are a zsh command generator"
    assert_not_contains "$prompt" "ADDITIONAL INSTRUCTIONS"
}

test_multiline_custom_prompt() {
    setup_test_env
    
    # Set multiline custom prompt
    export ZSH_AI_SYSTEM_PROMPT="Line 1
Line 2
Line 3"
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that default is included AND multiline custom prompt is preserved
    assert_contains "$prompt" "You are a zsh command generator"
    assert_contains "$prompt" "ADDITIONAL INSTRUCTIONS:"
    assert_contains "$prompt" "Line 1"
    assert_contains "$prompt" "Line 2"  
    assert_contains "$prompt" "Line 3"
}

test_special_characters_in_prompt() {
    setup_test_env
    
    # Set prompt with special characters
    export ZSH_AI_SYSTEM_PROMPT='Prefer $HOME over ~ and "double quotes" work'
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Check that special characters are preserved in the additional instructions
    assert_contains "$prompt" "You are a zsh command generator"
    assert_contains "$prompt" 'Prefer $HOME over ~ and "double quotes" work'
}

test_core_functionality_always_present() {
    setup_test_env
    
    # Set a custom prompt that could be problematic if it replaced the default
    export ZSH_AI_SYSTEM_PROMPT="Be very verbose and explain everything in detail"
    
    local prompt=$(_zsh_ai_get_system_prompt)
    
    # Ensure core instructions are STILL present
    assert_contains "$prompt" "Output ONLY the raw command"
    assert_contains "$prompt" "no explanations, no markdown, no backticks"
    # And the custom instruction is added
    assert_contains "$prompt" "Be very verbose and explain everything in detail"
}

# Run tests
echo "Running system prompt tests..."
test_default_system_prompt
test_custom_prompt_extends_default
test_empty_custom_prompt_uses_default
test_multiline_custom_prompt
test_special_characters_in_prompt
test_core_functionality_always_present