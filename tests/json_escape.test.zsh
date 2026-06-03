#!/usr/bin/env zsh

# Test suite for JSON escaping functionality
source "${0:A:h}/test_helper.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"

# Test helper function
test_json_escape() {
    local input="$1"
    local expected="$2"
    local result=$(_zsh_ai_escape_json "$input")
    
    if [[ "$result" != "$expected" ]]; then
        printf "  Input:    %q\n" "$input"
        printf "  Expected: %q\n" "$expected"
        printf "  Got:      %q\n" "$result"
        TEST_FAILED=1
        return 1
    fi
}

echo "Testing JSON escaping function..."

# Basic escaping tests
run_test "Simple string" test_json_escape "hello world" "hello world"
run_test "Double quotes" test_json_escape 'hello "world"' 'hello \"world\"'
run_test "Backslashes" test_json_escape 'hello\world' 'hello\\world'
run_test "Backslash before quote" test_json_escape 'hello\"world' 'hello\\\"world'

# Control character tests
run_test "Newline" test_json_escape $'hello\nworld' $'hello\\nworld'
run_test "Tab" test_json_escape $'hello\tworld' $'hello\\tworld'
run_test "Carriage return" test_json_escape $'hello\rworld' $'hello\\rworld'
run_test "Backspace" test_json_escape $'hello\bworld' $'hello\\bworld'
run_test "Form feed" test_json_escape $'hello\fworld' $'hello\\fworld'

# Complex combinations
run_test "Multiple escapes" test_json_escape $'line1\n"quoted"\ttab' $'line1\\n\\"quoted\\"\\ttab'
run_test "Path with spaces" test_json_escape '/Users/name/My Documents/file.txt' '/Users/name/My Documents/file.txt'
run_test "JSON in string" test_json_escape '{"key": "value"}' '{\"key\": \"value\"}'

# Edge cases
run_test "Empty string" test_json_escape "" ""
run_test "Only quotes" test_json_escape '"""' '\"\"\"'
run_test "Only backslashes" test_json_escape '\\\\' '\\\\\\\\'
run_test "Mixed control chars" test_json_escape $'start\n\r\t\b\fend' $'start\\n\\r\\t\\b\\fend'

# Test with potential problematic characters from the issue
run_test "Command with port" test_json_escape "kill process on port 3002" "kill process on port 3002"

# Test removal of other control characters
run_test "Null character" test_json_escape $'hello\0world' 'helloworld'
run_test "Bell character" test_json_escape $'hello\aworld' 'helloworld'
run_test "Vertical tab" test_json_escape $'hello\vworld' 'helloworld'

# Real-world scenario from context building
run_test "Directory listing" test_json_escape $'Current directory: /tmp\nFiles: test.txt, data.json' $'Current directory: /tmp\\nFiles: test.txt, data.json'
run_test "Git status" test_json_escape $'Git: branch=main, status=dirty\nOS: Darwin' $'Git: branch=main, status=dirty\\nOS: Darwin'

echo ""
echo "All tests completed!"
finish_tests
