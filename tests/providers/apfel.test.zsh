#!/usr/bin/env zsh

# Tests for the Apfel provider
source "${0:A:h}/../test_helper.zsh"
source "$PLUGIN_DIR/lib/config.zsh"
source "$PLUGIN_DIR/lib/context.zsh"
source "$PLUGIN_DIR/lib/providers/apfel.zsh"
source "$PLUGIN_DIR/lib/utils.zsh"

setup_apfel_test() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"
    export ZSH_AI_APFEL_URL="http://127.0.0.1:11435/v1/chat/completions"
    unset OPENAI_API_KEY ZSH_AI_OPENAI_API_KEY
    APFEL_TEST_BODY=''
    APFEL_TEST_STATUS="200"
    APFEL_TEST_CURL_STATUS="0"
    APFEL_TEST_ARGS_FILE=$(mktemp)
    APFEL_TEST_PAYLOAD_FILE=$(mktemp)

    curl() {
        local payload=""
        local previous=""
        local argument
        for argument in "$@"; do
            [[ "$previous" == "--data-binary" ]] && payload="$argument"
            previous="$argument"
        done
        print -l -- "$@" > "$APFEL_TEST_ARGS_FILE"
        print -rn -- "$payload" > "$APFEL_TEST_PAYLOAD_FILE"
        print -rn -- "$APFEL_TEST_BODY"$'\n'"$APFEL_TEST_STATUS"
        return "$APFEL_TEST_CURL_STATUS"
    }
}

teardown_apfel_test() {
    rm -f "$APFEL_TEST_ARGS_FILE" "$APFEL_TEST_PAYLOAD_FILE"
    teardown_test_env
    unset APFEL_TEST_BODY APFEL_TEST_STATUS APFEL_TEST_CURL_STATUS
    unset APFEL_TEST_ARGS_FILE APFEL_TEST_PAYLOAD_FILE
}

test_complete_response_returns_command() {
    setup_apfel_test
    export OPENAI_API_KEY="hosted-key"
    export ZSH_AI_OPENAI_API_KEY="proxy-key"
    APFEL_TEST_BODY='{"choices":[{"finish_reason":"stop","message":{"content":"printf '\''%s\\n'\'' '\''café'\''"}}]}'

    local result
    result=$(_zsh_ai_query_apfel "show café")
    assert_equals "$?" "0"
    assert_equals "$result" "printf '%s\\n' 'café'"
    local arguments=$(cat "$APFEL_TEST_ARGS_FILE")
    local payload=$(cat "$APFEL_TEST_PAYLOAD_FILE")
    assert_equals "${arguments%%$'\n'*}" "--disable"
    assert_not_contains "$arguments" "Authorization: Bearer"
    assert_contains "$arguments" "--noproxy"
    assert_contains "$payload" '"max_tokens": 256'
    assert_contains "$payload" '"tool_choice": "none"'

    teardown_apfel_test
}



test_rejects_unusable_completion_content() {
    local body
    for body in \
        '{"choices":[{"finish_reason":"stop","message":{"content":""}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":"   "}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":null}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":123}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":999999999999999999999999999999999}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":"```zsh\npwd\n```"}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{"content":"pwd\nls"}}]}' \
        '{"choices":[{"finish_reason":"stop","message":{}}]}' \
        'not json'; do
        setup_apfel_test
        APFEL_TEST_BODY="$body"
        local result
        result=$(_zsh_ai_query_apfel "list files")
        assert_equals "$?" "1"
        assert_contains "$result" "Error: Apfel returned an unusable response."
        teardown_apfel_test
    done
}


test_rejects_incomplete_and_tool_responses() {
    setup_apfel_test
    APFEL_TEST_BODY='{"choices":[{"finish_reason":"length","message":{"content":"find . -type"}}]}'

    local result
    result=$(_zsh_ai_query_apfel "find large files")
    assert_equals "$?" "1"
    assert_contains "$result" "incomplete response"
    teardown_apfel_test

    setup_apfel_test
    APFEL_TEST_BODY='{"choices":[{"finish_reason":"stop","message":{"content":"ls","tool_calls":[{"id":"call_1"}]}}]}'

    result=$(_zsh_ai_query_apfel "list files")
    assert_equals "$?" "1"
    assert_contains "$result" "tool call"
    teardown_apfel_test
}

test_reports_transport_and_http_errors() {
    setup_apfel_test
    APFEL_TEST_CURL_STATUS="7"

    local result
    result=$(_zsh_ai_query_apfel "list files")
    assert_equals "$?" "1"
    assert_contains "$result" "Failed to connect to Apfel"
    teardown_apfel_test

    setup_apfel_test
    APFEL_TEST_CURL_STATUS="28"

    result=$(_zsh_ai_query_apfel "list files")
    assert_equals "$?" "1"
    assert_contains "$result" "generation timed out"
    teardown_apfel_test

    setup_apfel_test
    APFEL_TEST_STATUS="500"
    APFEL_TEST_BODY='{"error":{"message":"internal failure"}}'

    result=$(_zsh_ai_query_apfel "list files")
    assert_equals "$?" "1"
    assert_contains "$result" "request failed (HTTP 500)"
    assert_contains "$result" "internal failure"
    teardown_apfel_test
}


start_apfel_fixture() {
    local response_file="$1"
    local request_file="$2"
    local headers_file="$3"
    local port_file="$4"

    perl -MIO::Socket::INET -e '
        my ($response_file, $request_file, $headers_file, $port_file) = @ARGV;
        my $server = IO::Socket::INET->new(
            LocalAddr => "127.0.0.1", LocalPort => 0, Proto => "tcp", Listen => 1, ReuseAddr => 1
        ) or die "listen: $!";
        open my $port, ">", $port_file or die "port: $!";
        print {$port} $server->sockport;
        close $port;
        my $client = $server->accept or exit 1;
        my $headers = "";
        while (defined(my $line = <$client>)) {
            $headers .= $line;
            last if $line eq "\r\n";
        }
        my ($length) = $headers =~ /Content-Length:\s*(\d+)/i;
        my $body = "";
        read($client, $body, $length || 0);
        open my $request, ">", $request_file or die "request: $!";
        print {$request} $body;
        open my $header_file, ">", $headers_file or die "headers: $!";
        print {$header_file} $headers;
        close $header_file;
        close $request;
        open my $response, "<", $response_file or die "response: $!";
        local $/;
        my $payload = <$response>;
        close $response;
        print {$client} "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " . length($payload) . "\r\nConnection: close\r\n\r\n" . $payload;
        close $client;
    ' "$response_file" "$request_file" "$headers_file" "$port_file" &
    APFEL_FIXTURE_PID=$!

    local attempt
    for attempt in {1..50}; do
        [[ -s "$port_file" ]] && return 0
        sleep 0.1
    done
    return 1
}

test_real_curl_path_escapes_request_data() {
    setup_test_env
    export ZSH_AI_PROVIDER="apfel"
    export OPENAI_API_KEY="hosted-key"
    export ZSH_AI_OPENAI_API_KEY="proxy-key"
    unfunction curl 2>/dev/null

    local fixture_dir=$(mktemp -d)
    local response_file="$fixture_dir/response.json"
    local request_file="$fixture_dir/request.json"
    local headers_file="$fixture_dir/headers.txt"
    local port_file="$fixture_dir/port"
    print -rn -- '{"choices":[{"finish_reason":"stop","message":{"content":"printf '\''%s\\n'\'' ok"}}]}' > "$response_file"

    start_apfel_fixture "$response_file" "$request_file" "$headers_file" "$port_file"
    local fixture_status=$?
    if (( fixture_status != 0 )); then
        TEST_FAILED=1
        cleanup_test_dir "$fixture_dir"
        teardown_test_env
        return 1
    fi
    export ZSH_AI_APFEL_URL="http://127.0.0.1:$(cat "$port_file")/v1/chat/completions"

    local result
    result=$(_zsh_ai_query_apfel $'quote " newline\n$dollar `backtick` -leading')
    local result_status=$?
    wait "$APFEL_FIXTURE_PID"

    assert_equals "$result_status" "0"
    assert_equals "$result" "printf '%s\\n' ok"
    local request=$(perl -MJSON::PP -0777 -e '
        my $payload = decode_json(<>);
        print join("\n", $payload->{model}, $payload->{tool_choice}, $payload->{messages}[1]{content});
    ' "$request_file")
    assert_contains "$request" "apple-foundationmodel"
    assert_contains "$request" "none"
    assert_contains "$request" 'quote " newline'
    assert_contains "$request" '$dollar `backtick` -leading'
    local headers=$(cat "$headers_file")
    assert_not_contains "$headers" "Authorization: Bearer"
    assert_not_contains "$headers" "hosted-key"
    assert_not_contains "$headers" "proxy-key"

    cleanup_test_dir "$fixture_dir"
    teardown_test_env
}

echo "Running Apfel provider tests..."
run_test "Returns a complete Apfel command" test_complete_response_returns_command
run_test "Rejects unusable Apfel completion content" test_rejects_unusable_completion_content
run_test "Rejects incomplete and tool-call Apfel completions" test_rejects_incomplete_and_tool_responses
run_test "Reports Apfel transport and HTTP errors" test_reports_transport_and_http_errors
run_test "Uses real curl with escaped request data" test_real_curl_path_escapes_request_data
finish_tests
