#!/usr/bin/env zsh
# Test helper utilities for zsh-ai tests

# Source the plugin files
export ZSH_AI_TEST_MODE=1
PLUGIN_DIR="${0:A:h:h}"

# Mock functions storage
typeset -gA MOCKED_COMMANDS
typeset -gA MOCK_OUTPUTS
typeset -gA MOCK_EXIT_CODES
typeset -gA CALL_COUNTS

# Initialize mock for a command
mock_command() {
    local cmd="$1"
    local output="${2:-}"
    local exit_code="${3:-0}"
    
    MOCKED_COMMANDS[$cmd]=1
    MOCK_OUTPUTS[$cmd]="$output"
    MOCK_EXIT_CODES[$cmd]="$exit_code"
    CALL_COUNTS[$cmd]=0
    
    # Create function to override command
    eval "
    $cmd() {
        CALL_COUNTS[$cmd]=\$((CALL_COUNTS[$cmd] + 1))
        if [[ -n \"\${MOCK_OUTPUTS[$cmd]}\" ]]; then
            echo \"\${MOCK_OUTPUTS[$cmd]}\"
        fi
        return \${MOCK_EXIT_CODES[$cmd]}
    }
    "
}

# Restore mocked command
unmock_command() {
    local cmd="$1"
    unset "MOCKED_COMMANDS[$cmd]"
    unset "MOCK_OUTPUTS[$cmd]"
    unset "MOCK_EXIT_CODES[$cmd]"
    unset "CALL_COUNTS[$cmd]"
    unfunction "$cmd" 2>/dev/null
}

# Reset all mocks
reset_mocks() {
    for cmd in ${(k)MOCKED_COMMANDS}; do
        unmock_command "$cmd"
    done
}

# Assert command was called
assert_called() {
    local cmd="$1"
    local expected_times="${2:-1}"
    local actual_times="${CALL_COUNTS[$cmd]:-0}"
    
    if [[ $actual_times -ne $expected_times ]]; then
        echo "Expected $cmd to be called $expected_times times, but was called $actual_times times"
        return 1
    fi
}

# Mock curl for API requests
mock_curl_response() {
    local response="$1"
    local exit_code="${2:-0}"
    
    # Store response and exit code in global variables
    export MOCK_CURL_RESPONSE="$response"
    export MOCK_CURL_EXIT_CODE="$exit_code"
    export MOCK_CURL_ARGS_FILE=$(mktemp)
    
    # Create a global curl function
    function curl() {
        # Log arguments to file since this might be run in a subshell
        print -r -- "$@" > "$MOCK_CURL_ARGS_FILE"

        if [[ "$MOCK_CURL_EXIT_CODE" -ne 0 ]]; then
            return "$MOCK_CURL_EXIT_CODE"
        fi
        print -r -- "$MOCK_CURL_RESPONSE"
        return 0
    }
}

# Mock jq command
mock_jq() {
    local available="${1:-true}"
    if [[ "$available" == "true" ]]; then
        # Mock command -v jq to return success
        command() {
            if [[ "$1" == "-v" ]] && [[ "$2" == "jq" ]]; then
                echo "/usr/bin/jq"
                return 0
            fi
            builtin command "$@"
        }
        # Also mock jq itself to parse JSON properly
        jq() {
            local args="$@"
            local input=$(cat)
            # Handle -r flag
            local raw_output=false
            if [[ "$args" == *"-r"* ]]; then
                raw_output=true
                args="${args//-r/}"
            fi
            
            # Parse based on the jq query
            local result=""
            if [[ "$args" == *".content[0].text"* ]]; then
                # For Anthropic responses
                result=$(echo "$input" | sed -n 's/.*"text":"\([^"]*\(\\.[^"]*\)*\)".*/\1/p' | sed 's/\\"/"/g')
            elif [[ "$args" == *".error.message"* ]]; then
                # For error responses
                result=$(echo "$input" | sed -n 's/.*"message":"\([^"]*\(\\.[^"]*\)*\)".*/\1/p' | sed 's/\\"/"/g')
            elif [[ "$args" == *".error"* ]]; then
                # For Ollama error responses
                result=$(echo "$input" | sed -n 's/.*"error":"\([^"]*\(\\.[^"]*\)*\)".*/\1/p' | sed 's/\\"/"/g')
            elif [[ "$args" == *".response"* ]]; then
                # For Ollama responses - handle escaped quotes and newlines
                # First extract the value, then unescape
                result=$(echo "$input" | perl -0777 -ne 'if (/"response":\s*"([^"\\]*(\\.[^"\\]*)*)"/) { $val = $1; $val =~ s/\\n/\n/g; $val =~ s/\\"/"/g; print $val; }')
            elif [[ "$args" == *".candidates[0].content.parts[0].text"* ]]; then
                # For Gemini responses
                result=$(print -r -- "$input" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"\([^"]*\)"/\1/')
            fi
            
            # Return result or empty based on // empty handling
            if [[ -n "$result" ]]; then
                echo "$result"
            elif [[ "$args" == *"// empty"* ]]; then
                # jq returns nothing for empty
                return 0
            else
                return 1
            fi
        }
    else
        command() {
            if [[ "$1" == "-v" ]] && [[ "$2" == "jq" ]]; then
                return 1
            fi
            builtin command "$@"
        }
    fi
}

# Setup test environment
setup_test_env() {
    # Set test environment variables
    export ZSH_AI_PROVIDER=""
    export ANTHROPIC_API_KEY=""
    export ZSH_AI_MODEL=""
    
    # Reset mocks
    reset_mocks
}

# Teardown test environment
teardown_test_env() {
    reset_mocks
    # Clean up curl mock temp file if it exists
    if [[ -n "$MOCK_CURL_ARGS_FILE" && -f "$MOCK_CURL_ARGS_FILE" ]]; then
        rm -f "$MOCK_CURL_ARGS_FILE"
    fi
    # Unfunction any mocked commands
    unfunction command 2>/dev/null
    unfunction jq 2>/dev/null
    unfunction curl 2>/dev/null
    unset ZSH_AI_PROVIDER
    unset ANTHROPIC_API_KEY
    unset ZSH_AI_MODEL
    unset ZSH_AI_TEST_MODE
}

# Assert string contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo "Expected '$haystack' to contain '$needle'"
        return 1
    fi
}

# Assert string equals
assert_equals() {
    local actual="$1"
    local expected="$2"
    if [[ "$actual" != "$expected" ]]; then
        echo "Expected '$expected' but got '$actual'"
        return 1
    fi
}

# Assert string does not contain
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected '$haystack' to not contain '$needle'"
        return 1
    fi
}

# Assert greater than
assert_greater_than() {
    local actual="$1"
    local expected="$2"
    if [[ "$actual" -le "$expected" ]]; then
        echo "Expected '$actual' to be greater than '$expected'"
        return 1
    fi
}

# Capture function output
capture_output() {
    local func="$1"
    shift
    local output
    output=$("$func" "$@" 2>&1)
    echo "$output"
}

# Create temporary test directory
create_test_dir() {
    local test_dir=$(mktemp -d)
    echo "$test_dir"
}

# Cleanup temporary test directory
cleanup_test_dir() {
    local test_dir="$1"
    [[ -d "$test_dir" ]] && rm -rf "$test_dir"
}