#!/usr/bin/env zsh

# OpenAI Codex OAuth auth flow helpers for zsh-ai

_ZSH_AI_CODEX_CLIENT_ID="${_ZSH_AI_CODEX_CLIENT_ID:-app_EMoamEEZ73f0CkXaXp7hrann}"
_ZSH_AI_CODEX_REDIRECT_URI="https://auth.openai.com/deviceauth/callback"
: ${_ZSH_AI_CODEX_AUTH_FILE:="${ZSH_AI_DATA_DIR:-$(_zsh_ai_data_dir)}/openai/auth.json"}
_ZSH_AI_CODEX_LOGIN_REQUIRED_MESSAGE="Error: Not logged in to ChatGPT/Codex. Run \`zsh-ai-codex login\`."
_ZSH_AI_CODEX_RELOGIN_REQUIRED_MESSAGE="Error: Run \`zsh-ai-codex login\` to sign in again."

_zsh_ai_json_get_string() {
    local json="$1"
    local key="$2"

    if command -v jq >/dev/null 2>&1; then
        printf "%s" "$json" | jq -r --arg key "$key" 'if .[$key] | type == "string" then .[$key] else empty end' 2>/dev/null
        return
    fi

    printf "%s" "$json" | perl -MJSON::PP -e '
        my $key = shift @ARGV;
        my $json = do { local $/; <STDIN> };
        my $data = eval { decode_json($json) };
        exit 0 if !$data || ref($data) ne "HASH";
        my $value = $data->{$key};
        print $value if defined $value && !ref($value);
    ' "$key" 2>/dev/null
}

_zsh_ai_json_get_number() {
    local json="$1"
    local key="$2"

    if command -v jq >/dev/null 2>&1; then
        printf "%s" "$json" | jq -r --arg key "$key" '.[$key] as $value | if ($value | type) == "number" then $value elif ($value | type) == "string" and ($value | test("^\\d+(?:\\.\\d+)?$")) then $value else empty end' 2>/dev/null
        return
    fi

    printf "%s" "$json" | perl -MJSON::PP -e '
        my $key = shift @ARGV;
        my $json = do { local $/; <STDIN> };
        my $data = eval { decode_json($json) };
        exit 0 if !$data || ref($data) ne "HASH";
        my $value = $data->{$key};
        print $value if defined $value && $value =~ /^\d+(?:\.\d+)?$/;
    ' "$key" 2>/dev/null
}

_zsh_ai_json_get_error_code() {
    local json="$1"

    printf "%s" "$json" | perl -MJSON::PP -e '
        my $json = do { local $/; <STDIN> };
        my $data = eval { decode_json($json) };
        exit 0 if !$data || ref($data) ne "HASH";

        my $code = $data->{code};
        if ((!defined($code) || ref($code)) && ref($data->{error}) eq "HASH") {
            $code = $data->{error}->{code};
        }
        if ((!defined($code) || ref($code)) && defined($data->{error}) && !ref($data->{error})) {
            $code = $data->{error};
        }
        print $code if defined $code && !ref($code);
    ' 2>/dev/null
}

_zsh_ai_json_get_error_message() {
    local json="$1"

    printf "%s" "$json" | perl -MJSON::PP -e '
        my $json = do { local $/; <STDIN> };
        my $data = eval { decode_json($json) };
        exit 0 if !$data || ref($data) ne "HASH";

        my $message = $data->{error_description};
        $message = $data->{message} if (!defined($message) || ref($message)) && defined($data->{message}) && !ref($data->{message});
        $message = $data->{detail} if (!defined($message) || ref($message)) && defined($data->{detail}) && !ref($data->{detail});
        if ((!defined($message) || ref($message)) && ref($data->{error}) eq "HASH") {
            $message = $data->{error}->{message};
            $message = $data->{error}->{code} if (!defined($message) || ref($message)) && defined($data->{error}->{code}) && !ref($data->{error}->{code});
        }
        if ((!defined($message) || ref($message)) && defined($data->{error}) && !ref($data->{error})) {
            $message = $data->{error};
        }
        print $message if defined $message && !ref($message);
    ' 2>/dev/null
}

_zsh_ai_codex_extract_account_id_from_token() {
    local token="$1"

    [[ -z "$token" ]] && return 0

    # Parse JWT token - see https://www.jwt.io/introduction
    printf "%s" "$token" | perl -MMIME::Base64=decode_base64url -MJSON::PP -e '
        my $token = do { local $/; <STDIN> };

        # Split header, payload, and signature
        my @parts = split /\./, $token;
        exit 0 if @parts < 2;

        # Decode the payload
        my $json = eval { decode_base64url($parts[1]) };
        my $data = eval { decode_json($json) };
        exit 0 if !$data || ref($data) ne "HASH";

        # Extract account_id
        my $account_id = $data->{chatgpt_account_id};
        if (!$account_id && ref($data->{"https://api.openai.com/auth"}) eq "HASH") {
            $account_id = $data->{"https://api.openai.com/auth"}->{chatgpt_account_id};
        }
        $account_id ||= $data->{"https://api.openai.com/auth.chatgpt_account_id"};
        if (!$account_id && ref($data->{organizations}) eq "ARRAY" && ref($data->{organizations}->[0]) eq "HASH") {
            $account_id = $data->{organizations}->[0]->{id};
        }
        print $account_id if defined $account_id && !ref($account_id);
    ' 2>/dev/null
}

_zsh_ai_codex_extract_account_id() {
    local id_token="$1"
    local access_token="$2"
    local account_id

    account_id=$(_zsh_ai_codex_extract_account_id_from_token "$id_token")
    if [[ -z "$account_id" ]]; then
        # Mirror OpenCode's Codex plugin: refresh responses may omit id_token,
        # while access_token can still be a JWT carrying ChatGPT account claims.
        # Opaque/non-JWT access tokens simply produce no account ID here.
        account_id=$(_zsh_ai_codex_extract_account_id_from_token "$access_token")
    fi
    printf "%s" "$account_id"
}

_zsh_ai_codex_load_auth() {
    local auth_file="$_ZSH_AI_CODEX_AUTH_FILE"
    local json

    if [[ ! -f "$auth_file" ]]; then
        echo "$_ZSH_AI_CODEX_LOGIN_REQUIRED_MESSAGE"
        return 1
    fi

    json=$(<"$auth_file")
    typeset -g _ZSH_AI_CODEX_ACCESS_TOKEN="$(_zsh_ai_json_get_string "$json" "access_token")"
    typeset -g _ZSH_AI_CODEX_REFRESH_TOKEN="$(_zsh_ai_json_get_string "$json" "refresh_token")"
    typeset -g _ZSH_AI_CODEX_EXPIRES_AT="$(_zsh_ai_json_get_number "$json" "expires_at")"
    typeset -g _ZSH_AI_CODEX_ACCOUNT_ID="$(_zsh_ai_json_get_string "$json" "account_id")"

    if [[ -z "$_ZSH_AI_CODEX_ACCESS_TOKEN" || -z "$_ZSH_AI_CODEX_REFRESH_TOKEN" ]]; then
        echo "$_ZSH_AI_CODEX_LOGIN_REQUIRED_MESSAGE"
        return 1
    fi

    return 0
}

_zsh_ai_codex_write_auth() {
    local access_token="$1"
    local refresh_token="$2"
    local expires_at="$3"
    local account_id="$4"
    local auth_file="$_ZSH_AI_CODEX_AUTH_FILE"
    local auth_dir="${auth_file:h}"
    local old_umask
    local escaped_access_token=$(_zsh_ai_escape_json "$access_token")
    local escaped_refresh_token=$(_zsh_ai_escape_json "$refresh_token")
    local escaped_account_id=$(_zsh_ai_escape_json "$account_id")
    local json_payload

    if [[ -z "$access_token" || -z "$refresh_token" || -z "$expires_at" ]]; then
        return 1
    fi

    mkdir -p -- "$auth_dir" || return 1
    chmod 700 -- "$auth_dir" 2>/dev/null

    json_payload=$(
        cat <<EOF
{
  "type": "codex",
  "access_token": "$escaped_access_token",
  "refresh_token": "$escaped_refresh_token",
  "expires_at": $expires_at,
  "account_id": "$escaped_account_id"
}
EOF
    )

    old_umask=$(umask)
    umask 077
    print -r -- "$json_payload" >|"$auth_file"
    local write_status=$?
    umask "$old_umask"
    [[ $write_status -ne 0 ]] && return $write_status
    chmod 600 -- "$auth_file" 2>/dev/null
}

_zsh_ai_codex_refresh() {
    local refresh_token="${1:-$_ZSH_AI_CODEX_REFRESH_TOKEN}"
    local response
    local access_token
    local new_refresh_token
    local expires_in
    local expires_at
    local id_token
    local account_id

    if [[ -z "$refresh_token" ]]; then
        echo "$_ZSH_AI_CODEX_RELOGIN_REQUIRED_MESSAGE"
        return 1
    fi

    response=$(curl -s "${ZSH_AI_CODEX_ISSUER}/oauth/token" \
        --header "content-type: application/x-www-form-urlencoded" \
        --data-urlencode "grant_type=refresh_token" \
        --data-urlencode "refresh_token=$refresh_token" \
        --data-urlencode "client_id=$_ZSH_AI_CODEX_CLIENT_ID" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "$_ZSH_AI_CODEX_RELOGIN_REQUIRED_MESSAGE"
        return 1
    fi

    access_token=$(_zsh_ai_json_get_string "$response" "access_token")
    new_refresh_token=$(_zsh_ai_json_get_string "$response" "refresh_token")
    expires_in=$(_zsh_ai_json_get_number "$response" "expires_in")
    id_token=$(_zsh_ai_json_get_string "$response" "id_token")

    if [[ -z "$access_token" ]]; then
        echo "$_ZSH_AI_CODEX_RELOGIN_REQUIRED_MESSAGE"
        return 1
    fi

    [[ -z "$new_refresh_token" ]] && new_refresh_token="$refresh_token"
    [[ -z "$expires_in" ]] && expires_in=3600
    expires_at=$(($(_zsh_ai_now_ms) + expires_in * 1000))
    account_id=$(_zsh_ai_codex_extract_account_id "$id_token" "$access_token")
    [[ -z "$account_id" ]] && account_id="$_ZSH_AI_CODEX_ACCOUNT_ID"

    _zsh_ai_codex_write_auth "$access_token" "$new_refresh_token" "$expires_at" "$account_id" || return 1

    typeset -g _ZSH_AI_CODEX_ACCESS_TOKEN="$access_token"
    typeset -g _ZSH_AI_CODEX_REFRESH_TOKEN="$new_refresh_token"
    typeset -g _ZSH_AI_CODEX_EXPIRES_AT="$expires_at"
    typeset -g _ZSH_AI_CODEX_ACCOUNT_ID="$account_id"
}

_zsh_ai_codex_refresh_if_needed() {
    local now_ms
    local refresh_window_ms=300000

    _zsh_ai_codex_load_auth || return 1

    now_ms=$(_zsh_ai_now_ms)
    if [[ -z "$_ZSH_AI_CODEX_EXPIRES_AT" || "$_ZSH_AI_CODEX_EXPIRES_AT" -le $((now_ms + refresh_window_ms)) ]]; then
        _zsh_ai_codex_refresh || return 1
    fi
}

_zsh_ai_codex_login() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: zsh-ai-codex login"
        return 1
    fi

    local usercode_response
    local device_auth_id
    local user_code
    local verification_uri
    local interval
    local expires_in
    local started_at
    local token_response
    local token_body
    local token_status
    local authorization_code
    local code_verifier
    local exchange_response
    local access_token
    local refresh_token
    local id_token
    local token_expires_in
    local expires_at
    local account_id
    local error_code
    local error_message

    usercode_response=$(curl -s "${ZSH_AI_CODEX_ISSUER}/api/accounts/deviceauth/usercode" \
        --header "content-type: application/json" \
        --header "User-Agent: zsh-ai" \
        --data "{\"client_id\":\"$_ZSH_AI_CODEX_CLIENT_ID\"}" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start Codex login"
        return 1
    fi

    device_auth_id=$(_zsh_ai_json_get_string "$usercode_response" "device_auth_id")
    user_code=$(_zsh_ai_json_get_string "$usercode_response" "user_code")
    [[ -z "$user_code" ]] && user_code=$(_zsh_ai_json_get_string "$usercode_response" "usercode")
    verification_uri="${ZSH_AI_CODEX_ISSUER}/codex/device"
    interval=$(_zsh_ai_json_get_number "$usercode_response" "interval")
    expires_in=$(_zsh_ai_json_get_number "$usercode_response" "expires_in")
    [[ -z "$interval" ]] && interval=5
    [[ -z "$expires_in" ]] && expires_in=900

    if [[ -z "$device_auth_id" || -z "$user_code" ]]; then
        error_message=$(_zsh_ai_json_get_error_message "$usercode_response")
        if [[ -n "$error_message" ]]; then
            echo "Error: Unable to start Codex login: $error_message"
        else
            echo "Error: Unable to start Codex login"
        fi
        return 1
    fi

    echo "Open this URL on any device: $verification_uri"
    echo "Enter this code: $user_code"
    echo "Waiting for authorization..."

    started_at=$(date +%s)
    while true; do
        token_response=$(curl -s -w $'\n%{http_code}' "${ZSH_AI_CODEX_ISSUER}/api/accounts/deviceauth/token" \
            --header "content-type: application/json" \
            --header "User-Agent: zsh-ai" \
            --data "{\"device_auth_id\":\"$(_zsh_ai_escape_json "$device_auth_id")\",\"user_code\":\"$(_zsh_ai_escape_json "$user_code")\"}" 2>&1)

        if [[ $? -ne 0 ]]; then
            echo "Error: Codex login polling failed"
            return 1
        fi

        token_status="${token_response##*$'\n'}"
        token_body="${token_response%$'\n'*}"
        if [[ ! "$token_status" == <-> ]]; then
            token_status=200
            token_body="$token_response"
        fi

        error_code=$(_zsh_ai_json_get_error_code "$token_body")
        error_message=$(_zsh_ai_json_get_error_message "$token_body")

        if [[ "$token_status" == "200" ]]; then
            authorization_code=$(_zsh_ai_json_get_string "$token_body" "authorization_code")
            code_verifier=$(_zsh_ai_json_get_string "$token_body" "code_verifier")
            [[ -n "$authorization_code" && -n "$code_verifier" ]] && break
        elif [[ "$token_status" == "403" || "$token_status" == "404" ]]; then
            if [[ "$error_code" != "deviceauth_authorization_pending" && "$error_message" != *"authorization is pending"* ]]; then
                if [[ -n "$error_message" ]]; then
                    echo "Codex login was not authorized: $error_message"
                else
                    echo "Codex login was not authorized."
                fi
                return 1
            fi
        else
            if [[ -n "$error_message" ]]; then
                echo "Codex login was not authorized: $error_message"
            else
                echo "Codex login was not authorized."
            fi
            return 1
        fi

        if (($(date +%s) - started_at >= expires_in)); then
            echo "Codex login expired. Run zsh-ai-codex login to try again."
            return 1
        fi
        sleep "$interval"
    done

    exchange_response=$(curl -s "${ZSH_AI_CODEX_ISSUER}/oauth/token" \
        --header "content-type: application/x-www-form-urlencoded" \
        --data-urlencode "grant_type=authorization_code" \
        --data-urlencode "code=$authorization_code" \
        --data-urlencode "redirect_uri=$_ZSH_AI_CODEX_REDIRECT_URI" \
        --data-urlencode "client_id=$_ZSH_AI_CODEX_CLIENT_ID" \
        --data-urlencode "code_verifier=$code_verifier" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to complete Codex login"
        return 1
    fi

    access_token=$(_zsh_ai_json_get_string "$exchange_response" "access_token")
    refresh_token=$(_zsh_ai_json_get_string "$exchange_response" "refresh_token")
    token_expires_in=$(_zsh_ai_json_get_number "$exchange_response" "expires_in")
    id_token=$(_zsh_ai_json_get_string "$exchange_response" "id_token")
    [[ -z "$token_expires_in" ]] && token_expires_in=3600

    if [[ -z "$access_token" || -z "$refresh_token" ]]; then
        error_message=$(_zsh_ai_json_get_error_message "$exchange_response")
        if [[ -n "$error_message" ]]; then
            echo "Error: Failed to complete Codex login: $error_message"
        else
            echo "Error: Failed to complete Codex login"
        fi
        return 1
    fi

    expires_at=$(($(_zsh_ai_now_ms) + token_expires_in * 1000))
    account_id=$(_zsh_ai_codex_extract_account_id "$id_token" "$access_token")

    _zsh_ai_codex_write_auth "$access_token" "$refresh_token" "$expires_at" "$account_id" || {
        echo "Error: Failed to write Codex auth file"
        return 1
    }

    echo "Signed in with ChatGPT/Codex."
}

_zsh_ai_codex_logout() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: zsh-ai-codex logout"
        return 1
    fi

    local auth_file="$_ZSH_AI_CODEX_AUTH_FILE"
    rm -f -- "$auth_file"
    echo "Signed out of ChatGPT/Codex."
}

_zsh_ai_codex_status() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: zsh-ai-codex status"
        return 1
    fi

    local auth_file="$_ZSH_AI_CODEX_AUTH_FILE"
    local now_ms
    local seconds_left

    if [[ ! -f "$auth_file" ]]; then
        echo "Signed out of ChatGPT/Codex."
        return 1
    fi

    _zsh_ai_codex_load_auth >/dev/null || return 1
    echo "Signed in with ChatGPT/Codex."
    [[ -n "$_ZSH_AI_CODEX_ACCOUNT_ID" ]] && echo "Account ID: $_ZSH_AI_CODEX_ACCOUNT_ID"
    if [[ -n "$_ZSH_AI_CODEX_EXPIRES_AT" ]]; then
        now_ms=$(_zsh_ai_now_ms)
        seconds_left=$(((_ZSH_AI_CODEX_EXPIRES_AT - now_ms) / 1000))
        if ((seconds_left > 0)); then
            echo "Access token expires in about $((seconds_left / 60)) minutes."
        else
            echo "Access token is expired and will refresh on next use."
        fi
    fi
}
