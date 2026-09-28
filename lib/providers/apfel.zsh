#!/usr/bin/env zsh

# Apfel API provider for zsh-ai

_zsh_ai_parse_apfel_completion() {
    if command -v jq >/dev/null 2>&1; then
        jq -j '
            .choices[0] as $choice |
            if ($choice | type) != "object" or ($choice.message | type) != "object" then "invalid"
            elif $choice.message.tool_calls? != null then "tool"
            elif $choice.finish_reason == "length" then "length"
            elif $choice.finish_reason != "stop" then "reason"
            elif ($choice.message.content | type) != "string" then "invalid"
            elif ($choice.message.content | test("\\S")) != true then "invalid"
            else "ok\n" + $choice.message.content
            end
        ' 2>/dev/null
    else
        perl -MJSON::PP -MEncode=decode,FB_CROAK -MB=svref_2object,SVf_POK -0777 -e '
            my $input = do { local $/; <STDIN> };
            my $data = eval {
                JSON::PP->new->allow_bignum->utf8(0)->decode(decode("UTF-8", $input, FB_CROAK))
            };
            binmode STDOUT, ":encoding(UTF-8)";
            unless (ref($data) eq "HASH"
                && ref($data->{choices}) eq "ARRAY"
                && ref($data->{choices}[0]) eq "HASH") {
                print "invalid";
                exit;
            }
            my $choice = $data->{choices}[0];
            my $message = $choice->{message};
            unless (ref($message) eq "HASH") {
                print "invalid";
                exit;
            }
            if (exists($message->{tool_calls}) && defined($message->{tool_calls})) {
                print "tool";
            } elsif (defined($choice->{finish_reason}) && $choice->{finish_reason} eq "length") {
                print "length";
            } elsif (!defined($choice->{finish_reason}) || $choice->{finish_reason} ne "stop") {
                print "reason";
            } else {
                my $content = $message->{content};
                my $content_is_string = defined($content)
                    && !ref($content)
                    && (svref_2object(\$content)->FLAGS & SVf_POK);
                print !$content_is_string || $content !~ /\S/
                    ? "invalid"
                    : "ok\n$content";
            }
        '
    fi
}

_zsh_ai_parse_apfel_error() {
    if command -v jq >/dev/null 2>&1; then
        jq -j -r 'if (.error.message | type) == "string" then .error.message else empty end' 2>/dev/null
    else
        perl -MJSON::PP -MEncode=decode,FB_CROAK -0777 -e '
            my $input = do { local $/; <STDIN> };
            my $data = eval {
                JSON::PP->new->utf8(0)->decode(decode("UTF-8", $input, FB_CROAK))
            };
            binmode STDOUT, ":encoding(UTF-8)";
            exit 0 unless ref($data) eq "HASH" && ref($data->{error}) eq "HASH";
            my $message = $data->{error}{message};
            print $message if defined($message) && !ref($message);
        ' 2>/dev/null
    fi
}

_zsh_ai_clean_apfel_command() {
    perl -0777 -pe '
        s/\A\s+//;
        s/\s+\z//;
        if (/\A```[A-Za-z0-9_+.-]*[ \t]*\r?\n(.*)\r?\n```\z/s) {
            $_ = $1;
            s/\A\s+//;
            s/\s+\z//;
        }
    '
}

_zsh_ai_apfel_http_error() {
    local http_status="$1"
    local body="$2"
    local message=$(printf '%s' "$body" | _zsh_ai_parse_apfel_error)
    message=$(printf '%s' "$message" | LC_ALL=C tr -cd '\11\40-\176')
    message="${message:0:200}"
    local lower_message="${message:l}"

    if [[ "$lower_message" == *"apple intelligence"* || "$lower_message" == *"model asset"* || "$lower_message" == *"model unavailable"* || "$lower_message" == *"assets are loading"* ]]; then
        echo "Error: Apfel's model is unavailable. Check Apple Intelligence and model readiness."
    elif [[ "$lower_message" == *"guardrail"* || "$lower_message" == *"safety"* || "$lower_message" == *"refus"* ]]; then
        echo "Error: Apfel refused the request because of its guardrails."
    elif [[ "$lower_message" == *"context"* || "$lower_message" == *"token limit"* ]]; then
        echo "Error: Apfel's context limit was exceeded. Shorten the request or ZSH_AI_PROMPT_EXTEND."
    elif [[ "$http_status" == "429" ]]; then
        echo "Error: Apfel rate-limited the request. Try again later."
    elif [[ "$http_status" == 5* ]]; then
        echo "Error: Apfel server failed (HTTP $http_status).${message:+ $message}"
    else
        echo "Error: Apfel request failed (HTTP $http_status).${message:+ $message}"
    fi
}

_zsh_ai_query_apfel() {
    local query="$1"
    local context=$(_zsh_ai_build_context)
    local system_prompt=$(_zsh_ai_get_system_prompt "$context")
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")
    local escaped_query=$(_zsh_ai_escape_json "$query")
    local payload=$(cat <<EOF
{
    "model": "apple-foundationmodel",
    "messages": [
        {"role": "system", "content": "$escaped_system_prompt"},
        {"role": "user", "content": "$escaped_query"}
    ],
    "temperature": 0.3,
    "max_tokens": $ZSH_AI_APFEL_MAX_TOKENS,
    "stream": false,
    "tool_choice": "none"
}
EOF
)


    local body_file=$(mktemp) || {
        echo "Error: Unable to create a temporary file for the Apfel response."
        return 1
    }
    local curl_output
    curl_output=$(curl --disable --silent --show-error --noproxy '*' \
        --connect-timeout 5 --max-time 90 \
        --output "$body_file" --write-out '%{http_code}' \
        --request POST \
        --header "content-type: application/json" \
        --data-binary "$payload" \
        "$ZSH_AI_APFEL_URL" 2>&1)
    local curl_status=$?
    local body=$(cat "$body_file")
    rm -f "$body_file"

    if (( curl_status != 0 )); then
        if (( curl_status == 28 )); then
            echo "Error: Apfel generation timed out. Try again or shorten the request."
        else
            echo "Error: Failed to connect to Apfel at $ZSH_AI_APFEL_URL. Start Apfel and check the port; Ollama also uses port 11434 by default."
        fi
        return 1
    fi

    if [[ "$curl_output" != <-> || "$curl_output" -lt 200 || "$curl_output" -ge 300 ]]; then
        _zsh_ai_apfel_http_error "$curl_output" "$body"
        return 1
    fi

    local parsed=$(printf '%s' "$body" | _zsh_ai_parse_apfel_completion)
    local parse_status=$?
    if (( parse_status != 0 )); then
        echo "Error: Apfel returned an unusable response."
        return 1
    fi

    local result
    case "$parsed" in
        $'ok\n'*)
            result="${parsed#ok$'\n'}"
            ;;
        tool)
            echo "Error: Apfel returned a tool call instead of a command."
            return 1
            ;;
        length)
            echo "Error: Apfel returned an incomplete response. Shorten the request or increase ZSH_AI_APFEL_MAX_TOKENS."
            return 1
            ;;
        reason)
            echo "Error: Apfel returned an unsupported completion reason."
            return 1
            ;;
        *)
            echo "Error: Apfel returned an unusable response."
            return 1
            ;;
    esac

    result=$(printf '%s' "$result" | _zsh_ai_clean_apfel_command)
    if [[ -z "${result//[[:space:]]/}" ]]; then
        echo "Error: Apfel returned an empty response."
        return 1
    fi
    if [[ "$result" == *$'\n'* || "$result" == *$'\r'* ]]; then
        echo "Error: Apfel returned multiple lines instead of one command."
        return 1
    fi

    printf '%s' "$result"
}
