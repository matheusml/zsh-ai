#!/usr/bin/env zsh

# Tests for OpenAI Codex OAuth provider

# Source test helper and the files we're testing
source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/openai.zsh"
source "${PLUGIN_DIR}/lib/providers/openai_codex/auth.zsh"
source "${PLUGIN_DIR}/lib/providers/openai_codex/response.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

echo "Running OpenAI Codex provider tests..."

test_openai_codex_auth_passes_validation_without_key() {
    unset OPENAI_API_KEY
    unset ZSH_AI_OPENAI_API_KEY
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_OPENAI_URL="https://api.openai.com/v1/chat/completions"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "0"
}

test_openai_rejects_invalid_auth_mode() {
    export ZSH_AI_PROVIDER="openai"
    export ZSH_AI_OPENAI_AUTH="bad"

    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "Invalid ZSH_AI_OPENAI_AUTH"
}

test_codex_parse_top_level_output_text() {
    local result=$(_zsh_ai_codex_parse_response '{"output_text":"ls -la"}')
    assert_equals "$result" "ls -la"
}

test_codex_parse_nested_output_text() {
    local response='{"output":[{"type":"message","content":[{"type":"output_text","text":"pwd"}]}]}'
    local result=$(_zsh_ai_codex_parse_response "$response")
    assert_equals "$result" "pwd"
}

test_codex_parse_sse_output_text_delta() {
    local response=$'event: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"ls"}\n\nevent: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":" -la"}\n\nevent: response.completed\ndata: {"type":"response.completed"}\n'
    local result=$(_zsh_ai_codex_parse_response "$response")
    assert_equals "$result" "ls -la"
}

test_codex_parse_sse_output_text_done() {
    local response=$'event: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"wrong"}\n\nevent: response.output_text.done\ndata: {"type":"response.output_text.done","text":"pwd"}\n'
    local result=$(_zsh_ai_codex_parse_response "$response")
    assert_equals "$result" "pwd"
}

test_codex_parse_sse_error() {
    local response=$'event: error\ndata: {"type":"error","message":"invalid request"}\n'
    local result
    result=$(_zsh_ai_codex_parse_response "$response")
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "API Error: invalid request"
}

test_codex_parse_error_response() {
    local result
    result=$(_zsh_ai_codex_parse_response '{"error":{"message":"bad token"}}')
    local exit_code=$?

    assert_equals "$exit_code" "1"
    assert_contains "$result" "API Error: bad token"
}

test_codex_parse_top_level_error_messages() {
    local result

    result=$(_zsh_ai_codex_parse_response '{"message":"invalid request body"}')
    assert_contains "$result" "API Error: invalid request body"

    result=$(_zsh_ai_codex_parse_response '{"detail":"stream must be true"}')
    assert_contains "$result" "API Error: stream must be true"

    result=$(_zsh_ai_codex_parse_response '{"error":"unsupported parameter"}')
    assert_contains "$result" "API Error: unsupported parameter"
}

test_codex_parse_response_without_jq() {
    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    local result=$(_zsh_ai_codex_parse_response '{"output_text":"echo test"}')
    unfunction command 2>/dev/null
    assert_equals "$result" "echo test"
}

test_codex_json_helpers_use_jq_when_available() {
    local calls_file=$(mktemp)

    jq() {
        print -r -- "$*" >> "$calls_file"
        local key=""
        local previous_arg=""
        local mode="string"
        [[ "$*" == *'type == "number"'* ]] && mode="number"

        for arg in "$@"; do
            if [[ "$previous_arg" == "key" ]]; then
                key="$arg"
                break
            fi
            previous_arg="$arg"
        done

        perl -MJSON::PP -e '
            my ($key, $mode) = @ARGV;
            my $json = do { local $/; <STDIN> };
            my $data = eval { decode_json($json) };
            exit 0 if !$data || ref($data) ne "HASH";
            my $value = $data->{$key};
            exit 0 if !defined($value) || ref($value);
            print $value;
        ' "$key" "$mode"
    }

    local string_result=$(_zsh_ai_json_get_string '{"name":"codex","count":3,"interval":"1"}' "name")
    local number_result=$(_zsh_ai_json_get_number '{"name":"codex","count":3,"interval":"1"}' "count")
    local numeric_string_result=$(_zsh_ai_json_get_number '{"name":"codex","count":3,"interval":"1"}' "interval")
    local calls=$(<"$calls_file")
    unfunction jq 2>/dev/null
    rm -f -- "$calls_file"

    assert_equals "$string_result" "codex"
    assert_equals "$number_result" "3"
    assert_equals "$numeric_string_result" "1"
    assert_contains "$calls" "--arg key name"
    assert_contains "$calls" "--arg key count"
    assert_contains "$calls" "--arg key interval"
}

test_codex_json_helpers_fallback_without_jq() {
    command() {
        if [[ "$1" == "-v" && "$2" == "jq" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    local string_result=$(_zsh_ai_json_get_string '{"name":"codex","count":3,"interval":"1"}' "name")
    local number_result=$(_zsh_ai_json_get_number '{"name":"codex","count":3,"interval":"1"}' "count")
    local numeric_string_result=$(_zsh_ai_json_get_number '{"name":"codex","count":3,"interval":"1"}' "interval")
    unfunction command 2>/dev/null

    assert_equals "$string_result" "codex"
    assert_equals "$number_result" "3"
    assert_equals "$numeric_string_result" "1"
}

test_codex_writes_auth_file_with_private_permissions() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"

    _zsh_ai_codex_write_auth "access-token" "refresh-token" "9999999999999" "account-id"
    local exit_code=$?
    local auth_json=$(<"$_ZSH_AI_CODEX_AUTH_FILE")
    local file_mode=$(stat -c "%a" "$_ZSH_AI_CODEX_AUTH_FILE")
    local dir_mode=$(stat -c "%a" "$temp_dir")
    rm -rf -- "$temp_dir"

    assert_equals "$exit_code" "0"
    assert_contains "$auth_json" '"access_token": "access-token"'
    assert_equals "$file_mode" "600"
    assert_equals "$dir_mode" "700"
}

test_codex_request_uses_responses_endpoint_payload_and_headers() {
    local temp_dir=$(mktemp -d)
    local args_file=$(mktemp)
    local payload_file=$(mktemp)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_OPENAI_MODEL="gpt-5.4-mini"
    export ZSH_AI_CODEX_URL="https://chatgpt.com/backend-api/codex/responses"
    _zsh_ai_codex_write_auth "access-token" "refresh-token" "9999999999999" "account-id"

    curl() {
        if [[ "$*" == *"backend-api/codex/responses"* ]]; then
            echo "$*" > "$args_file"
            local prev_arg=""
            for arg in "$@"; do
                if [[ "$prev_arg" == "--data" ]]; then
                    print -r -- "$arg" > "$payload_file"
                    break
                fi
                prev_arg="$arg"
            done
            printf '%s\n200' '{"output_text":"ls -la"}'
            return 0
        fi
        return 1
    }

    local result=$(_zsh_ai_query_openai "list files")
    local curl_args=$(<"$args_file")
    local payload=$(<"$payload_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$args_file" "$payload_file"

    assert_equals "$result" "ls -la"
    assert_contains "$curl_args" "https://chatgpt.com/backend-api/codex/responses"
    assert_contains "$curl_args" "Authorization: Bearer access-token"
    assert_contains "$curl_args" "ChatGPT-Account-ID: account-id"
    assert_contains "$curl_args" "accept: text/event-stream"
    assert_contains "$payload" '"stream": true'
    assert_not_contains "$payload" '"max_output_tokens"'
    assert_contains "$payload" '"store": false'
    assert_contains "$payload" '"instructions"'
    assert_contains "$payload" '"input"'
    assert_contains "$payload" '"role": "user"'
    assert_not_contains "$payload" '"role": "system"'
    assert_not_contains "$payload" '"verbosity"'
}

test_codex_http_400_surfaces_backend_message() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_CODEX_URL="https://chatgpt.com/backend-api/codex/responses"
    _zsh_ai_codex_write_auth "access-token" "refresh-token" "9999999999999" "account-id"

    curl() {
        if [[ "$*" == *"backend-api/codex/responses"* ]]; then
            printf '%s\n400' '{"message":"unsupported parameter: text"}'
            return 0
        fi
        return 1
    }

    local result
    result=$(_zsh_ai_query_openai "list files")
    local exit_code=$?
    rm -rf -- "$temp_dir"

    assert_equals "$exit_code" "1"
    assert_contains "$result" "API Error: unsupported parameter: text"
}

test_codex_request_omits_account_header_when_missing() {
    local temp_dir=$(mktemp -d)
    local args_file=$(mktemp)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_CODEX_URL="https://chatgpt.com/backend-api/codex/responses"
    _zsh_ai_codex_write_auth "access-token" "refresh-token" "9999999999999" ""

    curl() {
        if [[ "$*" == *"backend-api/codex/responses"* ]]; then
            echo "$*" > "$args_file"
            printf '%s\n200' '{"output_text":"pwd"}'
            return 0
        fi
        return 1
    }

    _zsh_ai_query_openai "where am i" >/dev/null
    local curl_args=$(<"$args_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$args_file"

    assert_not_contains "$curl_args" "ChatGPT-Account-ID"
}

test_codex_expired_token_refreshes_before_request() {
    local temp_dir=$(mktemp -d)
    local args_file=$(mktemp)
    local refresh_count_file=$(mktemp)
    print -r -- "0" > "$refresh_count_file"
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_CODEX_URL="https://chatgpt.com/backend-api/codex/responses"
    _zsh_ai_codex_write_auth "old-access" "old-refresh" "1" "account-id"

    curl() {
        if [[ "$*" == *"/oauth/token"* ]]; then
            local refresh_called=$(<"$refresh_count_file")
            refresh_called=$((refresh_called + 1))
            print -r -- "$refresh_called" > "$refresh_count_file"
            printf '%s' '{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}'
            return 0
        fi
        if [[ "$*" == *"backend-api/codex/responses"* ]]; then
            echo "$*" > "$args_file"
            printf '%s\n200' '{"output_text":"date"}'
            return 0
        fi
        return 1
    }

    local result=$(_zsh_ai_query_openai "date")
    local curl_args=$(<"$args_file")
    local refresh_called=$(<"$refresh_count_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$args_file" "$refresh_count_file"

    assert_equals "$result" "date"
    assert_equals "$refresh_called" "1"
    assert_contains "$curl_args" "Authorization: Bearer new-access"
}

test_codex_401_refreshes_and_retries_once() {
    local temp_dir=$(mktemp -d)
    local endpoint_count_file=$(mktemp)
    local refresh_count_file=$(mktemp)
    print -r -- "0" > "$endpoint_count_file"
    print -r -- "0" > "$refresh_count_file"
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    export ZSH_AI_OPENAI_AUTH="codex"
    export ZSH_AI_CODEX_URL="https://chatgpt.com/backend-api/codex/responses"
    _zsh_ai_codex_write_auth "old-access" "old-refresh" "9999999999999" "account-id"

    curl() {
        if [[ "$*" == *"/oauth/token"* ]]; then
            local refresh_called=$(<"$refresh_count_file")
            refresh_called=$((refresh_called + 1))
            print -r -- "$refresh_called" > "$refresh_count_file"
            printf '%s' '{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}'
            return 0
        fi
        if [[ "$*" == *"backend-api/codex/responses"* ]]; then
            local endpoint_calls=$(<"$endpoint_count_file")
            endpoint_calls=$((endpoint_calls + 1))
            print -r -- "$endpoint_calls" > "$endpoint_count_file"
            if [[ "$endpoint_calls" -eq 1 ]]; then
                printf '%s\n401' '{"error":{"message":"expired"}}'
            else
                printf '%s\n200' '{"output_text":"whoami"}'
            fi
            return 0
        fi
        return 1
    }

    local result=$(_zsh_ai_query_openai "who am i")
    local endpoint_calls=$(<"$endpoint_count_file")
    local refresh_called=$(<"$refresh_count_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$endpoint_count_file" "$refresh_count_file"

    assert_equals "$result" "whoami"
    assert_equals "$refresh_called" "1"
    assert_equals "$endpoint_calls" "2"
}

test_codex_missing_auth_file_prompts_login() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/missing.json"
    export ZSH_AI_OPENAI_AUTH="codex"

    local result
    result=$(_zsh_ai_query_openai "list files")
    local exit_code=$?
    rm -rf -- "$temp_dir"

    assert_equals "$exit_code" "1"
    assert_contains "$result" "zsh-ai-codex login"
}

test_codex_logout_deletes_auth_file() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    _zsh_ai_codex_write_auth "access-token" "refresh-token" "9999999999999" "account-id"

    zsh-ai-codex logout >/dev/null
    local exists=0
    [[ -f "$_ZSH_AI_CODEX_AUTH_FILE" ]] && exists=1
    rm -rf -- "$temp_dir"

    assert_equals "$exists" "0"
}

test_codex_status_does_not_print_tokens() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"
    _zsh_ai_codex_write_auth "secret-access" "secret-refresh" "9999999999999" "account-id"

    local result
    result=$(zsh-ai-codex status)
    rm -rf -- "$temp_dir"

    assert_contains "$result" "Signed in"
    assert_contains "$result" "account-id"
    assert_not_contains "$result" "secret-access"
    assert_not_contains "$result" "secret-refresh"
}

test_codex_login_writes_auth_file() {
    local temp_dir=$(mktemp -d)
    local call_count=0
    local usercode_args_file=$(mktemp)
    local token_args_file=$(mktemp)
    local token_payload_file=$(mktemp)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"

    curl() {
        call_count=$((call_count + 1))
        if [[ "$*" == *"deviceauth/usercode"* ]]; then
            print -r -- "$*" > "$usercode_args_file"
            printf '%s' '{"device_auth_id":"device-1","usercode":"ABCD-EFGH","verification_uri":"https://example.com/wrong-device","interval":"1","expires_in":60}'
            return 0
        fi
        if [[ "$*" == *"deviceauth/token"* ]]; then
            print -r -- "$*" > "$token_args_file"
            local prev_arg=""
            for arg in "$@"; do
                if [[ "$prev_arg" == "--data" ]]; then
                    print -r -- "$arg" > "$token_payload_file"
                    break
                fi
                prev_arg="$arg"
            done
            printf '%s\n200' '{"authorization_code":"auth-code","code_verifier":"verifier"}'
            return 0
        fi
        if [[ "$*" == *"/oauth/token"* ]]; then
            printf '%s' '{"access_token":"access-token","refresh_token":"refresh-token","expires_in":3600}'
            return 0
        fi
        return 1
    }

    local result
    result=$(zsh-ai-codex login)
    local exit_code=$?
    local auth_json=$(<"$_ZSH_AI_CODEX_AUTH_FILE")
    local usercode_args=$(<"$usercode_args_file")
    local token_args=$(<"$token_args_file")
    local token_payload=$(<"$token_payload_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$usercode_args_file" "$token_args_file" "$token_payload_file"

    assert_equals "$exit_code" "0"
    assert_contains "$result" "https://auth.openai.com/codex/device"
    assert_not_contains "$result" "https://example.com/wrong-device"
    assert_contains "$result" "Signed in"
    assert_contains "$auth_json" '"access_token": "access-token"'
    assert_contains "$auth_json" '"refresh_token": "refresh-token"'
    assert_contains "$usercode_args" "User-Agent: zsh-ai"
    assert_contains "$token_args" "User-Agent: zsh-ai"
    assert_contains "$token_payload" '"user_code":"ABCD-EFGH"'
}

test_codex_login_retries_pending_poll() {
    local temp_dir=$(mktemp -d)
    local poll_count_file=$(mktemp)
    print -r -- "0" > "$poll_count_file"
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"

    curl() {
        if [[ "$*" == *"deviceauth/usercode"* ]]; then
            printf '%s' '{"device_auth_id":"device-1","user_code":"ABCD-EFGH","interval":"0","expires_in":60}'
            return 0
        fi
        if [[ "$*" == *"deviceauth/token"* ]]; then
            local poll_count=$(<"$poll_count_file")
            poll_count=$((poll_count + 1))
            print -r -- "$poll_count" > "$poll_count_file"
            if [[ "$poll_count" -eq 1 ]]; then
                printf '%s\n403' '{"error":{"message":"Device authorization is pending. Please try again.","code":"deviceauth_authorization_pending"}}'
            else
                printf '%s\n200' '{"authorization_code":"auth-code","code_verifier":"verifier"}'
            fi
            return 0
        fi
        if [[ "$*" == *"/oauth/token"* ]]; then
            printf '%s' '{"access_token":"access-token","refresh_token":"refresh-token","expires_in":3600}'
            return 0
        fi
        return 1
    }

    local result
    result=$(zsh-ai-codex login)
    local exit_code=$?
    local poll_count=$(<"$poll_count_file")
    rm -rf -- "$temp_dir"
    rm -f -- "$poll_count_file"

    assert_equals "$exit_code" "0"
    assert_equals "$poll_count" "2"
    assert_contains "$result" "Signed in"
}

test_codex_login_surfaces_cancelled_poll() {
    local temp_dir=$(mktemp -d)
    typeset -g _ZSH_AI_CODEX_AUTH_FILE="$temp_dir/auth.json"

    curl() {
        if [[ "$*" == *"deviceauth/usercode"* ]]; then
            printf '%s' '{"device_auth_id":"device-1","user_code":"ABCD-EFGH","interval":"0","expires_in":60}'
            return 0
        fi
        if [[ "$*" == *"deviceauth/token"* ]]; then
            printf '%s\n403' '{"error":{"message":"sign-in cancelled","code":"access_denied"}}'
            return 0
        fi
        return 1
    }

    local result
    result=$(zsh-ai-codex login)
    local exit_code=$?
    rm -rf -- "$temp_dir"

    assert_equals "$exit_code" "1"
    assert_contains "$result" "sign-in cancelled"
}

run_test "OpenAI Codex auth passes validation without key" test_openai_codex_auth_passes_validation_without_key
run_test "OpenAI rejects invalid auth mode" test_openai_rejects_invalid_auth_mode
run_test "Codex parses top-level output_text" test_codex_parse_top_level_output_text
run_test "Codex parses nested output text" test_codex_parse_nested_output_text
run_test "Codex parses SSE output text delta" test_codex_parse_sse_output_text_delta
run_test "Codex parses SSE output text done" test_codex_parse_sse_output_text_done
run_test "Codex parses error response" test_codex_parse_error_response
run_test "Codex parses top-level error messages" test_codex_parse_top_level_error_messages
run_test "Codex parses SSE error" test_codex_parse_sse_error
run_test "Codex parser works without jq" test_codex_parse_response_without_jq
run_test "Codex JSON helpers use jq when available" test_codex_json_helpers_use_jq_when_available
run_test "Codex JSON helpers fall back without jq" test_codex_json_helpers_fallback_without_jq
run_test "Codex writes auth file with private permissions" test_codex_writes_auth_file_with_private_permissions
run_test "Codex request uses endpoint, payload, and headers" test_codex_request_uses_responses_endpoint_payload_and_headers
run_test "Codex HTTP 400 surfaces backend message" test_codex_http_400_surfaces_backend_message
run_test "Codex request omits missing account header" test_codex_request_omits_account_header_when_missing
run_test "Codex expired token refreshes before request" test_codex_expired_token_refreshes_before_request
run_test "Codex 401 refreshes and retries once" test_codex_401_refreshes_and_retries_once
run_test "Codex missing auth file prompts login" test_codex_missing_auth_file_prompts_login
run_test "Codex logout deletes auth file" test_codex_logout_deletes_auth_file
run_test "Codex status does not print tokens" test_codex_status_does_not_print_tokens
run_test "Codex login writes auth file" test_codex_login_writes_auth_file
run_test "Codex login retries pending poll" test_codex_login_retries_pending_poll
run_test "Codex login surfaces cancelled poll" test_codex_login_surfaces_cancelled_poll
finish_tests
