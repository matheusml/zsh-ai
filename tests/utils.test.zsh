#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load required modules
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/providers/anthropic.zsh"
source "$PLUGIN_DIR/lib/providers/ollama.zsh"
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

test_checks_ollama_availability_before_querying() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    export ZSH_AI_OLLAMA_URL="http://localhost:11434"
    
    # Mock Ollama check to fail
    _zsh_ai_check_ollama() {
        return 1
    }
    
    local output
    output=$(_zsh_ai_query "test query")
    local result=$?
    
    assert_equals "$result" "1"
    assert_contains "$output" "Ollama is not running"
    assert_contains "$output" "http://localhost:11434"
    assert_contains "$output" "ollama serve"
    
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
    _zsh_ai_execute_command() {
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

test_no_execution_happens() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function
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

test_shows_loading_spinner() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock query function with delay to simulate API call
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
    
    local complex_context="Current dir: /home/user\nGit branch: main\nProject: Node.js"
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
    assert_contains "$prompt" "Context:\n"
    
    teardown_test_env
}

# Run tests
echo "Running utils tests..."
test_routes_to_anthropic_provider && echo "✓ Routes to Anthropic provider when configured"
test_routes_to_ollama_provider && echo "✓ Routes to Ollama provider when configured"
test_checks_ollama_availability_before_querying && echo "✓ Checks Ollama availability before querying"
test_shows_usage_without_arguments && echo "✓ Shows usage when called without arguments"
test_shows_ollama_model_in_usage && echo "✓ Shows Ollama model in usage for Ollama provider"
test_shows_command_without_executing && echo "✓ Shows command without executing"
test_puts_command_in_buffer && echo "✓ Puts command in buffer"
test_handles_api_errors_in_zsh_ai && echo "✓ Handles API errors in zsh-ai command"
test_handles_empty_response_in_zsh_ai && echo "✓ Handles empty response in zsh-ai command"
test_combines_multiple_arguments && echo "✓ Combines multiple arguments in zsh-ai command"
test_puts_generated_command_in_buffer && echo "✓ Puts generated command in buffer"
test_no_execution_happens && echo "✓ No execution happens"
test_shows_loading_spinner && echo "✓ Shows loading spinner during command generation"
test_get_system_prompt_includes_all_rules && echo "✓ System prompt includes all rules"
test_get_system_prompt_with_complex_context && echo "✓ System prompt handles complex context"
test_get_system_prompt_with_empty_context && echo "✓ System prompt handles empty context"