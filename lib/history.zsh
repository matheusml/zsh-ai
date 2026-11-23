#!/usr/bin/env zsh

# Encrypted prompt history for zsh-ai. Needs openssl; without it nothing is stored.

_zsh_ai_history_dir() {
    echo "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-ai"
}

_zsh_ai_history_enabled() {
    case "${ZSH_AI_HISTORY:l}" in
        false|off|no|0|disabled) return 1 ;;
    esac
    command -v openssl &>/dev/null
}

# Create the random key on first use. Directory is 700 and key file is 600.
_zsh_ai_history_key_file() {
    local dir=$(_zsh_ai_history_dir)
    local key_file="$dir/history.key"
    if [[ ! -s "$key_file" ]]; then
        mkdir -p "$dir" && chmod 700 "$dir" || return 1
        ( umask 077 && openssl rand -base64 32 > "$key_file" ) || return 1
    fi
    echo "$key_file"
}

# Append one prompt. Each stored line is base64(AES-256-CBC(prompt)), so the file stays one record per line.
_zsh_ai_history_save() {
    _zsh_ai_history_enabled || return 0
    local prompt="$1"
    [[ -z "$prompt" ]] && return 0

    local key_file=$(_zsh_ai_history_key_file) || return 0
    local file="$(_zsh_ai_history_dir)/history.enc"
    local line=$(printf '%s' "$prompt" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$key_file" -base64 -A 2>/dev/null)
    [[ -z "$line" ]] && return 0

    ( umask 077 && printf '%s\n' "$line" >> "$file" )

    local lines=("${(@f)$(<"$file")}")
    if (( ${#lines} > ${ZSH_AI_HISTORY_MAX:-500} )); then
        ( umask 077 && printf '%s\n' "${(@)lines[-${ZSH_AI_HISTORY_MAX:-500},-1]}" > "$file" )
    fi
}

# Print decrypted prompts, oldest first. Lines that fail to decrypt are skipped.
_zsh_ai_history_load() {
    _zsh_ai_history_enabled || return 0
    local file="$(_zsh_ai_history_dir)/history.enc"
    local key_file="$(_zsh_ai_history_dir)/history.key"
    [[ -s "$file" && -s "$key_file" ]] || return 0

    local line plain
    while IFS= read -r line; do
        plain=$(printf '%s' "$line" | openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$key_file" -base64 -A 2>/dev/null)
        [[ -n "$plain" ]] && print -r -- "$plain"
    done < "$file"
}

# Up/down browsing state. index 0 means not browsing; 1..count are saved prompts;
# count+1 is the draft the user had typed before browsing.
typeset -ga _zsh_ai_hist_entries=()
typeset -gi _zsh_ai_hist_index=0
typeset -g _zsh_ai_hist_draft=""
typeset -g _zsh_ai_hist_shown=""

_zsh_ai_history_reset() {
    _zsh_ai_hist_index=0
    _zsh_ai_hist_shown=""
}

# For browsing, a bare "#" starts a prompt even before text is typed. Custom
# triggers still match exactly.
_zsh_ai_history_is_prompt_buffer() {
    local trigger="${ZSH_AI_TRIGGER:-# }"
    [[ "$BUFFER" == "$trigger"* ]] && return 0
    [[ "$trigger" == "# " && "$BUFFER" == "#" ]] && return 0
    return 1
}

# Move through saved prompts. $1 is -1 (older) or 1 (newer). Returns 1 when the
# key should fall back to the normal shell history.
_zsh_ai_history_step() {
    local direction="$1"
    local trigger="${ZSH_AI_TRIGGER:-# }"

    if (( _zsh_ai_hist_index == 0 )) || [[ "$BUFFER" != "$_zsh_ai_hist_shown" ]]; then
        _zsh_ai_history_is_prompt_buffer || return 1
        _zsh_ai_hist_entries=("${(@f)$(_zsh_ai_history_load)}")
        _zsh_ai_hist_entries=("${(@)_zsh_ai_hist_entries:#}")
        (( ${#_zsh_ai_hist_entries} > 0 )) || return 1
        _zsh_ai_hist_draft="$BUFFER"
        _zsh_ai_hist_index=$(( ${#_zsh_ai_hist_entries} + 1 ))
    fi

    local count=${#_zsh_ai_hist_entries}
    if (( direction < 0 )); then
        (( _zsh_ai_hist_index > 1 )) && (( _zsh_ai_hist_index-- ))
    else
        (( _zsh_ai_hist_index <= count )) || return 0
        (( _zsh_ai_hist_index++ ))
    fi

    if (( _zsh_ai_hist_index > count )); then
        BUFFER="$_zsh_ai_hist_draft"
    else
        BUFFER="$trigger${_zsh_ai_hist_entries[_zsh_ai_hist_index]}"
    fi
    CURSOR=$#BUFFER
    _zsh_ai_hist_shown="$BUFFER"
    return 0
}
