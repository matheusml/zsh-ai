#!/usr/bin/env zsh

# T3 Code provider for zsh-ai
#
# Uses the agent CLIs that T3 Code manages (Claude Code, Codex) with the same
# binary, config directory, and login T3 uses, read from T3's settings.json.
# Requests run as one-off, tool-less, non-persisted CLI calls, so nothing shows
# up in T3 and zsh-ai needs no API key.

# Print the T3 settings.json path.
_zsh_ai_t3_settings_file() {
    if [[ -n "$ZSH_AI_T3_SETTINGS" ]]; then
        print -r -- "$ZSH_AI_T3_SETTINGS"
    else
        print -r -- "${T3CODE_HOME:-$HOME/.t3}/userdata/settings.json"
    fi
}

# Map friendly names to T3 provider instance ids.
_zsh_ai_t3_instance_id() {
    case "${1:l}" in
        anthropic|claude|claudeagent) echo "claudeAgent" ;;
        openai|codex) echo "codex" ;;
        gemini|google) echo "gemini" ;;
        *) echo "$1" ;;
    esac
}

# Fast default model for each driver.
_zsh_ai_t3_default_model() {
    case "$1" in
        claudeAgent) echo "claude-haiku-5-5" ;;
        codex) echo "gpt-6-luna" ;;
        gemini) echo "gemini-3.8-flash" ;;
    esac
}

# Resolve a T3 provider instance to "driver binaryPath homePath enabled",
# separated by \x1f, from T3's settings.json. Without settings the instance id
# is used as the driver.
_zsh_ai_t3_resolve_instance() {
    local instance="$1"
    local settings=$(_zsh_ai_t3_settings_file)
    local resolved=""

    if [[ -r "$settings" ]]; then
        resolved=$(perl -MJSON::PP -0777 -e '
            my ($file, $id) = @ARGV;
            open(my $fh, "<", $file) or exit 0;
            my $data = eval { JSON::PP->new->decode(do { local $/; <$fh> }) };
            exit 0 unless ref($data) eq "HASH" && ref($data->{providerInstances}) eq "HASH";
            my $inst = $data->{providerInstances}{$id};
            exit 0 unless ref($inst) eq "HASH";
            my $cfg = ref($inst->{config}) eq "HASH" ? $inst->{config} : {};
            my @out = map { defined($_) && !ref($_) ? $_ : "" } (
                $inst->{driver}, $cfg->{binaryPath}, $cfg->{homePath},
                (exists $inst->{enabled} && !$inst->{enabled}) ? "disabled" : ""
            );
            s/[\x1f\n]//g for @out;
            print join("\x1f", @out);
        ' "$settings" "$instance" 2>/dev/null)
    fi

    local driver binary home enabled
    IFS=$'\x1f' read -r driver binary home enabled <<< "$resolved"
    [[ -z "$driver" ]] && driver="$instance"
    # T3 stores paths like ~/.codex-t3/personal; expand a leading ~.
    [[ "$binary" == "~"* ]] && binary="${HOME}${binary#\~}"
    [[ "$home" == "~"* ]] && home="${HOME}${home#\~}"
    print -r -- "${driver}"$'\x1f'"${binary}"$'\x1f'"${home}"$'\x1f'"${enabled}"
}

# Clean a model reply: trim and strip a surrounding markdown fence or backticks.
_zsh_ai_t3_clean_reply() {
    perl -MEncode=decode,encode -0777 -e '
        my $reply = decode("UTF-8", do { local $/; <STDIN> });
        $reply =~ s/\A\s+|\s+\z//g;
        if ($reply =~ /\A```[^\n]*\n(.*?)\n?```\z/s) {
            $reply = $1;
        } elsif ($reply =~ /\A`([^`\n]+)`\z/) {
            $reply = $1;
        }
        $reply =~ s/\A\s+|\s+\z//g;
        print encode("UTF-8", $reply);
    '
}

# Last non-empty stderr line, printable ASCII only, for error messages.
_zsh_ai_t3_error_line() {
    local text="$1"
    local -a lines
    lines=("${(@f)text}")
    local line
    for line in "${(@Oa)lines}"; do
        line=$(printf '%s' "$line" | LC_ALL=C tr -cd '\11\40-\176')
        [[ -n "${line// /}" ]] && { print -r -- "${line[1,200]}"; return; }
    done
}

_zsh_ai_t3_run_claude() {
    local binary="${1:-claude}" home="$2" model="$3" system_prompt="$4" query="$5" errfile="$6"
    local -a args env_args
    args=(-p --tools "" --no-session-persistence --strict-mcp-config --setting-sources ""
        --system-prompt "$system_prompt")
    [[ -n "$model" ]] && args+=(--model "$model")
    [[ -n "$home" ]] && env_args=(CLAUDE_CONFIG_DIR="$home")

    env "${env_args[@]}" "$binary" "${args[@]}" "$query" </dev/null 2>"$errfile"
}

_zsh_ai_t3_run_codex() {
    local binary="${1:-codex}" home="$2" model="$3" system_prompt="$4" query="$5" errfile="$6"
    local workdir=$(mktemp -d)
    local outfile="$workdir/last-message"
    local -a args env_args
    args=(exec --ephemeral --skip-git-repo-check --sandbox read-only --color never
        -C "$workdir" -c 'model_reasoning_effort="low"' -o "$outfile")
    [[ -n "$model" ]] && args+=(-m "$model")
    [[ -n "$home" ]] && env_args=(CODEX_HOME="$home")

    env "${env_args[@]}" "$binary" "${args[@]}" "${system_prompt}"$'\n\n'"User request: ${query}" \
        </dev/null >/dev/null 2>"$errfile"
    local exit_code=$?
    [[ -r "$outfile" ]] && cat "$outfile"
    rm -rf "$workdir"
    return $exit_code
}

_zsh_ai_t3_run_gemini() {
    local binary="${1:-gemini}" home="$2" model="$3" system_prompt="$4" query="$5" errfile="$6"
    local workdir=$(mktemp -d)
    local -a args
    args=(--approval-mode default --output-format text)
    [[ -n "$model" ]] && args+=(-m "$model")

    (cd "$workdir" && "$binary" "${args[@]}" -p "${system_prompt}"$'\n\n'"User request: ${query}" \
        </dev/null 2>"$errfile")
    local exit_code=$?
    rm -rf "$workdir"
    return $exit_code
}

_zsh_ai_query_t3() {
    local query="$1"

    local instance=$(_zsh_ai_t3_instance_id "$ZSH_AI_T3_PROVIDER")
    local resolved=$(_zsh_ai_t3_resolve_instance "$instance")
    local driver binary home enabled
    IFS=$'\x1f' read -r driver binary home enabled <<< "$resolved"

    if [[ "$enabled" == "disabled" ]]; then
        echo "Error: T3 provider '$instance' is disabled in T3 Code."
        return 1
    fi

    local default_binary runner
    case "$driver" in
        claudeAgent) default_binary="claude"; runner="_zsh_ai_t3_run_claude" ;;
        codex) default_binary="codex"; runner="_zsh_ai_t3_run_codex" ;;
        gemini) default_binary="gemini"; runner="_zsh_ai_t3_run_gemini" ;;
        *)
            echo "Error: T3 provider '$instance' (driver '$driver') is not supported. Use claudeAgent, codex, or gemini."
            return 1
            ;;
    esac
    [[ -z "$binary" ]] && binary="$default_binary"

    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "Error: '$binary' not found for T3 provider '$instance'. Install it or set its binary path in T3 Code."
        return 1
    fi

    local model="$ZSH_AI_T3_MODEL"
    [[ -z "$model" ]] && model=$(_zsh_ai_t3_default_model "$driver")

    local context=$(_zsh_ai_build_context)
    local system_prompt=$(_zsh_ai_get_system_prompt "$context")
    system_prompt="${system_prompt}"$'\n\n'"Do not use tools or run anything. Reply with exactly one zsh command."

    local errfile=$(mktemp)
    local output
    output=$("$runner" "$binary" "$home" "$model" "$system_prompt" "$query" "$errfile")
    local exit_code=$?
    local errors=$(<"$errfile")
    rm -f "$errfile"

    local result=$(printf '%s' "$output" | _zsh_ai_t3_clean_reply)

    if (( exit_code != 0 )); then
        local message=$(_zsh_ai_t3_error_line "$errors")
        [[ -z "$message" ]] && message=$(_zsh_ai_t3_error_line "$output")
        echo "Error: $binary failed (exit $exit_code).${message:+ $message}"
        return 1
    fi

    if [[ -z "$result" ]]; then
        local message=$(_zsh_ai_t3_error_line "$errors")
        echo "Error: $binary returned an empty reply.${message:+ $message}"
        return 1
    fi

    printf '%s' "$result"
}
