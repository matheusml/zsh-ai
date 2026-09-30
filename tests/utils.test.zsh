#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load required modules
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/providers/anthropic.zsh"
source "$PLUGIN_DIR/lib/providers/ollama.zsh"
source "$PLUGIN_DIR/lib/providers/apfel.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"

# Test functions

# _zsh_ai_query routing tests
test_routes_to_anthropic_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock Anthropic query function
    _zsh_ai_query_anthropic() {
        echo "anthropic:$1"
    }
    
    local output
    output=$(_zsh_ai_query "test query")
    assert_equals "$output" "anthropic:test query"
    
    teardown_test_env
}

test_routes_to_custom_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="custom"

    # Mock custom provider
    _zsh_ai_query_custom() {
        echo "custom:$1"
    }
    
    local output
    output=$(_zsh_ai_query "test query")
    assert_equals "$output" "custom:test query"

    teardown_test_env
}

test_provider_non_zero_exit_code() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"

    _zsh_ai_query_anthropic() {
        echo "Not prefixed with 'Error:'"
        return 1
    }

    # Capture output with stderr
    local output
    output=$(zsh-ai "test query" 2>&1)
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Failed to generate command"
    assert_contains "$output" "Not prefixed with 'Error:'"

    teardown_test_env
}

test_routes_to_ollama_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    
    # Mock Ollama check and query functions
    _zsh_ai_check_ollama() {
        return 0
    }
    
    _zsh_ai_query_ollama() {
        echo "ollama:$1"
    }
    
    local output
    output=$(_zsh_ai_query "test query")
    assert_equals "$output" "ollama:test query"
    
    teardown_test_env
}

test_routes_to_apfel_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"

    _zsh_ai_query_apfel() {
        echo "apfel:$1"
    }

    local output
    output=$(_zsh_ai_query "test query")
    assert_equals "$output" "apfel:test query"

    teardown_test_env
}

test_checks_ollama_availability_before_querying() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock Ollama check to fail (the real check prints the user-facing error itself)
    _zsh_ai_check_ollama() {
        echo "Error: mock check failed"
        return 1
    }

    _zsh_ai_query_ollama() {
        echo "should not run"
    }

    local output
    output=$(_zsh_ai_query "test query")
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "Error: mock check failed"
    assert_not_contains "$output" "should not run"

    teardown_test_env
}

# zsh-ai command tests
test_shows_usage_without_arguments() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    
    # Capture output through a subshell
    local output
    output=$(zsh-ai)
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Usage: zsh-ai"
    assert_contains "$output" "Example:"
    assert_contains "$output" "Current provider: anthropic"
    
    teardown_test_env
}

test_shows_ollama_model_in_usage() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    export ZSH_AI_OLLAMA_MODEL="llama3.2"
    
    # Capture output through a subshell
    local output
    output=$(zsh-ai)
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Current provider: ollama"
    assert_contains "$output" "Ollama model: llama3.2"
    
    teardown_test_env
}

test_shows_apfel_setup_and_active_endpoint() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"
    export ZSH_AI_APFEL_URL="http://127.0.0.1:11435/v1/chat/completions"

    local output
    output=$(zsh-ai)
    local result=$?

    assert_equals "$result" "1"
    assert_contains "$output" "brew install apfel"
    assert_contains "$output" "brew services start apfel"
    assert_contains "$output" 'export ZSH_AI_PROVIDER="apfel"'
    assert_contains "$output" "Apple Silicon"
    assert_contains "$output" "Apfel model: apple-foundationmodel"
    assert_contains "$output" "Apfel endpoint: http://127.0.0.1:11435/v1/chat/completions"

    teardown_test_env
}

test_shows_command_without_executing() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function
    _zsh_ai_query() {
        echo "echo 'Hello World'"
    }
    
    # Track eval execution - should NOT be called
    local eval_called=0
    eval() {
        eval_called=1
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai "say hello" >/dev/null 2>&1
    
    # Should put command in buffer but NOT execute it
    assert_equals "$eval_called" "0"
    assert_equals "$buffer_cmd" "echo 'Hello World'"
    
    teardown_test_env
}

test_puts_command_in_buffer() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function
    _zsh_ai_query() {
        echo "ls -la"
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai "list files" >/dev/null 2>&1
    
    # Should put command in buffer
    assert_equals "$buffer_cmd" "ls -la"
    
    teardown_test_env
}

test_handles_api_errors_in_zsh_ai() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function to return error
    _zsh_ai_query() {
        echo "Error: API connection failed"
    }
    
    # Capture output with stderr
    local output
    output=$(zsh-ai "test query" 2>&1)
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Failed to generate command"
    assert_contains "$output" "API connection failed"
    
    teardown_test_env
}

test_handles_empty_response_in_zsh_ai() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function to return empty
    _zsh_ai_query() {
        echo ""
    }
    
    # Capture output with stderr
    local output
    output=$(zsh-ai "test query" 2>&1)
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Failed to generate command"
    
    teardown_test_env
}

test_combines_multiple_arguments() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock execute command function
    _zsh_ai_query() {
        echo "find . -name '*.py'"
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai find all python files >/dev/null 2>&1
    
    # Should put command in buffer
    assert_equals "$buffer_cmd" "find . -name '*.py'"
    
    teardown_test_env
}

test_puts_generated_command_in_buffer() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock execute command function
    _zsh_ai_query() {
        echo "ls -la"
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai "list files" >/dev/null 2>&1
    
    # Should put command in buffer
    assert_equals "$buffer_cmd" "ls -la"
    
    teardown_test_env
}

test_no_execution_happens() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock execute command function
    _zsh_ai_query() {
        echo "pwd"
    }
    
    # Track eval execution - should NOT be called
    local eval_called=0
    eval() {
        eval_called=1
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai "show directory" >/dev/null 2>&1
    
    # Should NOT execute the command
    assert_equals "$eval_called" "0"
    # Should put command in buffer
    assert_equals "$buffer_cmd" "pwd"
    
    teardown_test_env
}

test_works_with_noclobber_set() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"

    # Simulate a user with noclobber in their zshrc (issue #46):
    # the tmpfile redirect must not fail on the file mktemp already created
    setopt localoptions noclobber

    # Mock query function
    _zsh_ai_query() {
        echo "ls -la"
    }

    # Mock print -z so the success path doesn't touch the buffer stack
    print() {
        if [[ "$1" == "-z" ]]; then
            :
        else
            builtin print "$@"
        fi
    }

    local output
    output=$(zsh-ai "list files" 2>&1)
    local result=$?

    assert_equals "$result" "0"
    assert_not_contains "$output" "Failed to generate command"

    teardown_test_env
}

test_shows_loading_spinner() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock execute command function with delay to simulate API call
    _zsh_ai_query() {
        sleep 0.3
        echo "ls -la"
    }
    
    # Mock print -z to capture buffer command
    local buffer_cmd=""
    print() {
        if [[ "$1" == "-z" ]]; then
            buffer_cmd="$2"
        else
            builtin print "$@"
        fi
    }
    
    zsh-ai "list files" >/dev/null 2>&1
    
    # Should put command in buffer
    assert_equals "$buffer_cmd" "ls -la"
    
    teardown_test_env
}

test_get_system_prompt_includes_all_rules() {
    setup_test_env
    
    local prompt=$(_zsh_ai_get_system_prompt "test context")
    
    # Check that all key parts of the prompt are present
    assert_contains "$prompt" "zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    assert_contains "$prompt" "Output ONLY the raw command"
    assert_contains "$prompt" "no explanations, no markdown, no backticks"
    assert_contains "$prompt" "single quotes"
    assert_contains "$prompt" "double quotes"
    assert_contains "$prompt" "variable expansion"
    assert_contains "$prompt" "Examples:"
    assert_contains "$prompt" "echo 'Hello World!'"
    assert_contains "$prompt" "Context:"
    assert_contains "$prompt" "test context"
    
    teardown_test_env
}

test_get_system_prompt_with_complex_context() {
    setup_test_env
    
    local complex_context=$'Current dir: /home/user\nGit branch: main\nProject: Node.js'
    local prompt=$(_zsh_ai_get_system_prompt "$complex_context")
    
    # Check that context is included at the end
    assert_contains "$prompt" "Context:"
    assert_contains "$prompt" "$complex_context"
    
    teardown_test_env
}

test_get_system_prompt_with_empty_context() {
    setup_test_env
    
    local prompt=$(_zsh_ai_get_system_prompt "")
    
    # Should still include the Context: header even if empty
    assert_contains "$prompt" "Context:"
    
    teardown_test_env
}

test_get_system_prompt_with_extension() {
    setup_test_env
    
    # Set custom prompt extension
    export ZSH_AI_PROMPT_EXTEND="Always prefer modern CLI tools. Use ripgrep instead of grep."
    
    local prompt=$(_zsh_ai_get_system_prompt "test context")
    
    # Check that core prompt is still present
    assert_contains "$prompt" "zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    
    # Check that extension is included
    assert_contains "$prompt" "Always prefer modern CLI tools"
    assert_contains "$prompt" "Use ripgrep instead of grep"
    
    # Check that context is still at the end
    assert_contains "$prompt" "Context:"
    assert_contains "$prompt" "test context"
    
    # Check proper ordering - extension should be between rules and context
    local prompt_text="$prompt"
    if [[ "$prompt_text" =~ "IMPORTANT RULES.*Always prefer modern CLI tools.*Context:" ]]; then
        # Test passes - ordering is correct
        :
    else
        echo "Error: Prompt extension not in correct position"
        return 1
    fi
    
    teardown_test_env
}

test_get_system_prompt_without_extension() {
    setup_test_env
    
    # Ensure no extension is set
    unset ZSH_AI_PROMPT_EXTEND
    
    local prompt=$(_zsh_ai_get_system_prompt "test context")
    
    # Should work exactly as before when no extension is set
    assert_contains "$prompt" "zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    assert_contains "$prompt" "Context:"
    assert_contains "$prompt" "test context"
    
    # Should not have extra newlines where extension would be
    local expected_pattern=$'glob patterns in quotes)\n\nContext:'
    assert_contains "$prompt" "$expected_pattern"
    
    teardown_test_env
}

test_get_system_prompt_with_multiline_extension() {
    setup_test_env
    
    # Set multi-line custom prompt extension
    export ZSH_AI_PROMPT_EXTEND="Additional rules:\n1. Prefer fd over find\n2. Use bat instead of cat\n3. Always use exa for ls commands"
    
    local prompt=$(_zsh_ai_get_system_prompt "test context")
    
    # Check that all lines of extension are included
    assert_contains "$prompt" "Additional rules:"
    assert_contains "$prompt" "1. Prefer fd over find"
    assert_contains "$prompt" "2. Use bat instead of cat"
    assert_contains "$prompt" "3. Always use exa for ls commands"
    
    teardown_test_env
}

test_get_system_prompt_with_empty_extension() {
    setup_test_env
    
    # Set empty extension (should behave same as unset)
    export ZSH_AI_PROMPT_EXTEND=""
    
    local prompt=$(_zsh_ai_get_system_prompt "test context")
    
    # Should work exactly as before when extension is empty
    assert_contains "$prompt" "zsh command generator"
    assert_contains "$prompt" "IMPORTANT RULES"
    assert_contains "$prompt" "Context:"
    assert_contains "$prompt" "test context"
    
    teardown_test_env
}

# Run tests
echo "Running utils tests..."
run_test "Routes to Anthropic provider when configured" test_routes_to_anthropic_provider
run_test "Routes to Ollama provider when configured" test_routes_to_ollama_provider
run_test "Routes to Apfel provider when configured" test_routes_to_apfel_provider
run_test "Routes to custom provider when configured" test_routes_to_custom_provider
run_test "Throws an error when provider returns non-zero exit code" test_provider_non_zero_exit_code
run_test "Checks Ollama availability before querying" test_checks_ollama_availability_before_querying
run_test "Shows usage when called without arguments" test_shows_usage_without_arguments
run_test "Shows Ollama model in usage for Ollama provider" test_shows_ollama_model_in_usage
run_test "Shows Apfel setup and active endpoint in usage" test_shows_apfel_setup_and_active_endpoint
run_test "Shows command without executing" test_shows_command_without_executing
run_test "Puts command in buffer" test_puts_command_in_buffer
run_test "Handles API errors in zsh-ai command" test_handles_api_errors_in_zsh_ai
run_test "Handles empty response in zsh-ai command" test_handles_empty_response_in_zsh_ai
run_test "Combines multiple arguments in zsh-ai command" test_combines_multiple_arguments
run_test "Puts generated command in buffer" test_puts_generated_command_in_buffer
run_test "No execution happens" test_no_execution_happens
run_test "Works with noclobber set" test_works_with_noclobber_set
run_test "Shows loading spinner during command generation" test_shows_loading_spinner
run_test "System prompt includes all rules" test_get_system_prompt_includes_all_rules
run_test "System prompt handles complex context" test_get_system_prompt_with_complex_context
run_test "System prompt handles empty context" test_get_system_prompt_with_empty_context
run_test "System prompt includes custom extension when set" test_get_system_prompt_with_extension
run_test "System prompt works without extension" test_get_system_prompt_without_extension
run_test "System prompt handles multiline extension" test_get_system_prompt_with_multiline_extension
run_test "System prompt handles empty extension" test_get_system_prompt_with_empty_extension
finish_tests
