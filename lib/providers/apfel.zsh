#!/usr/bin/env zsh

# Apfel API provider for zsh-ai

_zsh_ai_parse_apfel_completion() {
    perl -MJSON::PP -MEncode=decode,FB_CROAK -0777 -e '
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
            my $encoded = eval { JSON::PP->new->allow_bignum->encode($content) };
            if (!defined($encoded) || substr($encoded, 0, 1) ne q{"}) {
                print "invalid";
                exit;
            }
            $content =~ s/\A\s+//;
            $content =~ s/\s+\z//;
            print $content eq "" || $content =~ /\A```|```\z|[\r\n]/
                ? "invalid"
                : "ok\n$content";
        }
    '
}

_zsh_ai_parse_apfel_error() {
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
}

_zsh_ai_apfel_http_error() {
    local http_status="$1"
    local body="$2"
    local message=$(printf '%s' "$body" | _zsh_ai_parse_apfel_error)
    message=$(printf '%s' "$message" | LC_ALL=C tr -cd '\11\40-\176')
    message="${message:0:200}"
    echo "Error: Apfel request failed (HTTP $http_status).${message:+ $message}"
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
    "max_tokens": 256,
    "stream": false,
    "tool_choice": "none"
}
EOF
)

    local curl_output
    curl_output=$(curl --disable --silent --show-error --noproxy '*' \
        --connect-timeout 5 --max-time 90 \
        --write-out $'\n%{http_code}' \
        --request POST \
        --header "content-type: application/json" \
        --data-binary "$payload" \
        "$ZSH_AI_APFEL_URL" 2>&1)
    local curl_status=$?

    if (( curl_status != 0 )); then
        if (( curl_status == 28 )); then
            echo "Error: Apfel generation timed out. Try again or shorten the request."
        else
            echo "Error: Failed to connect to Apfel at $ZSH_AI_APFEL_URL. Start Apfel and check the port; Ollama also uses port 11434 by default."
        fi
        return 1
    fi

    local http_status="${curl_output[-3,-1]}"
    local body="${curl_output%$'\n'$http_status}"
    if [[ "$http_status" != <-> || "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
        _zsh_ai_apfel_http_error "$http_status" "$body"
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
            echo "Error: Apfel returned an incomplete response."
            return 1
            ;;
        *)
            echo "Error: Apfel returned an unusable response."
            return 1
            ;;
    esac

    printf '%s' "$result"
}
