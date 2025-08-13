#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load required modules
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"
source "$PLUGIN_DIR/lib/widget.zsh"

# Test functions

test_widget_initialization_creates_accept_line_widget() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock ZLE functions
    typeset -gA MOCKED_WIDGETS
    zle() {
        case "$1" in
            "-N")
                # Widget creation
                MOCKED_WIDGETS[$2]="$3"
                ;;
        esac
    }
    
    _zsh_ai_init_widget
    
    assert_equals "${MOCKED_WIDGETS[accept-line]}" "_zsh_ai_accept_line"
    
    teardown_test_env
}

test_normal_commands_execute_without_ai_processing() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    local ACCEPT_LINE_CALLED=0
    zle() {
        case "$1" in
            ".accept-line")
                ACCEPT_LINE_CALLED=1
                ;;
        esac
    }
    
    BUFFER="ls -la"
    _zsh_ai_accept_line
    
    assert_equals "$ACCEPT_LINE_CALLED" "1"
    
    teardown_test_env
}

test_multiline_ai_commands_execute_without_processing() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    local ACCEPT_LINE_CALLED=0
    zle() {
        case "$1" in
            ".accept-line")
                ACCEPT_LINE_CALLED=1
                ;;
        esac
    }
    
    BUFFER="# list files
and show details"
    _zsh_ai_accept_line
    
    assert_equals "$ACCEPT_LINE_CALLED" "1"
    
    teardown_test_env
}

test_ai_commands_starting_with_hash_are_processed() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function
    _zsh_ai_query() {
        echo "ls -la"
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "ls -la" 0
    mock_command "rm" "" 0
    
    # Mock ZLE functions
    local RESET_PROMPT_CALLED=0
    zle() {
        case "$1" in
            "reset-prompt")
                RESET_PROMPT_CALLED=1
                ;;
        esac
    }
    
    BUFFER="# list all files"
    CURSOR=0
    
    _zsh_ai_accept_line
    
    # Buffer should be replaced with command
    assert_equals "$BUFFER" "ls -la"
    assert_equals "$CURSOR" "6"
    assert_equals "$RESET_PROMPT_CALLED" "1"
    
    teardown_test_env
}

test_handles_api_errors_gracefully() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function to return error
    _zsh_ai_query() {
        echo "Error: API connection failed"
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "Error: API connection failed" 0
    mock_command "rm" "" 0
    
    # Mock print to capture output
    local printed_output=""
    print() {
        printed_output="$printed_output$@\n"
    }
    
    # Mock ZLE functions
    zle() {
        case "$1" in
            "reset-prompt")
                ;;
        esac
    }
    
    BUFFER="# invalid query"
    
    _zsh_ai_accept_line
    
    # Buffer should be cleared on error
    assert_equals "$BUFFER" ""
    assert_contains "$printed_output" "Failed to generate command"
    assert_contains "$printed_output" "API connection failed"
    
    teardown_test_env
}

test_shows_loading_animation_during_api_call() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function
    _zsh_ai_query() {
        echo "pwd"
    }
    
    # Mock kill to simulate running process then completion
    local kill_count=0
    kill() {
        kill_count=$((kill_count + 1))
        if [[ $kill_count -le 2 ]]; then
            return 0  # Process still running
        else
            return 1  # Process completed
        fi
    }
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "pwd" 0
    mock_command "rm" "" 0
    
    # Mock ZLE functions
    local REDISPLAY_COUNT=0
    zle() {
        case "$1" in
            "redisplay"|"-R")
                REDISPLAY_COUNT=$((REDISPLAY_COUNT + 1))
                ;;
            "reset-prompt")
                ;;
        esac
    }
    
    # Mock sleep
    mock_command "sleep" "" 0
    
    BUFFER="# show current directory"
    
    _zsh_ai_accept_line
    
    # Should have animated
    assert_greater_than "$REDISPLAY_COUNT" "0"
    
    teardown_test_env
}

test_preserves_original_buffer_during_animation() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function
    _zsh_ai_query() {
        echo "git status"
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "git status" 0
    mock_command "rm" "" 0
    
    # Mock ZLE functions
    zle() {
        case "$1" in
            "reset-prompt")
                ;;
        esac
    }
    
    local original_buffer="# check git status"
    BUFFER="$original_buffer"
    
    _zsh_ai_accept_line
    
    # Final buffer should be the command
    assert_equals "$BUFFER" "git status"
    
    teardown_test_env
}

test_handles_empty_api_response() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function to return empty
    _zsh_ai_query() {
        echo ""
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "" 0
    mock_command "rm" "" 0
    
    # Mock print to capture output
    local printed_output=""
    print() {
        printed_output="$printed_output$@\n"
    }
    
    # Mock ZLE functions
    zle() {
        case "$1" in
            "reset-prompt")
                ;;
        esac
    }
    
    BUFFER="# empty response"
    
    _zsh_ai_accept_line
    
    # Buffer should be cleared
    assert_equals "$BUFFER" ""
    assert_contains "$printed_output" "Failed to generate command"
    
    teardown_test_env
}

test_uses_temporary_file_for_api_response() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Track mktemp calls
    local mktemp_called=0
    local temp_file="/tmp/test.tmp"
    mktemp() {
        mktemp_called=1
        echo "$temp_file"
    }
    
    # Mock cat and rm
    mock_command "cat" "echo 'Hello World'" 0
    local rm_called=0
    rm() {
        rm_called=1
    }
    
    # Mock the query function
    _zsh_ai_query() {
        echo "echo 'Hello World'"
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock ZLE functions
    zle() {
        case "$1" in
            "reset-prompt")
                ;;
        esac
    }
    
    BUFFER="# say hello"
    
    _zsh_ai_accept_line
    
    assert_equals "$mktemp_called" "1"
    assert_equals "$rm_called" "1"
    
    teardown_test_env
}

test_handles_commands_with_special_characters() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    
    # Mock the query function
    _zsh_ai_query() {
        echo "echo 'Hello, World!'"
    }
    
    # Mock kill to simulate process completion
    mock_command "kill" "" 1
    
    # Mock mktemp and cat
    mktemp() {
        echo "/tmp/test.tmp"
    }
    mock_command "cat" "echo 'Hello, World!'" 0
    mock_command "rm" "" 0
    
    # Mock ZLE functions
    zle() {
        case "$1" in
            "reset-prompt")
                ;;
        esac
    }
    
    BUFFER="# print greeting"
    
    _zsh_ai_accept_line
    
    assert_equals "$BUFFER" "echo 'Hello, World!'"
    
    teardown_test_env
}

# Run tests
echo "Running widget tests..."
test_widget_initialization_creates_accept_line_widget && echo "✓ Widget initialization creates accept-line widget"
test_normal_commands_execute_without_ai_processing && echo "✓ Normal commands execute without AI processing"
test_multiline_ai_commands_execute_without_processing && echo "✓ Multiline AI commands execute without processing"
test_ai_commands_starting_with_hash_are_processed && echo "✓ AI commands starting with # are processed"
test_handles_api_errors_gracefully && echo "✓ Handles API errors gracefully"
test_shows_loading_animation_during_api_call && echo "✓ Shows loading animation during API call"
test_preserves_original_buffer_during_animation && echo "✓ Preserves original buffer during animation"
test_handles_empty_api_response && echo "✓ Handles empty API response"
test_uses_temporary_file_for_api_response && echo "✓ Uses temporary file for API response"
test_handles_commands_with_special_characters && echo "✓ Handles commands with special characters"