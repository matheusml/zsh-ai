# Implement ChatGPT/Codex OAuth Auth Mode

## Purpose

Add a terminal-only ChatGPT/Codex OAuth authentication path to `zsh-ai`, exposed as an OpenAI provider auth mode. The existing OpenAI API-key path must remain unchanged by default.

This plan is intended for a fresh agent session. It includes the current understanding, assumptions, implementation details, files to edit, and expected verification commands.

## Current Repository Context

This repository is a small zsh plugin that turns natural-language prompts into shell commands.

Important files:

- `zsh-ai.plugin.zsh`: sources config, context, utils, widget, and provider modules.
- `lib/config.zsh`: default config values and provider validation.
- `lib/context.zsh`: builds shell/project/git/OS context.
- `lib/utils.zsh`: builds prompts, routes provider calls, and implements the `zsh-ai` command.
- `lib/widget.zsh`: implements the `# ...` widget flow.
- `lib/providers/openai.zsh`: current OpenAI provider implementation using Chat Completions and API-key bearer auth.
- `lib/providers/openai_codex.zsh`: ChatGPT/Codex OAuth helpers, token management, and Codex Responses calls.
- `tests/config.test.zsh`: config validation tests.
- `tests/providers/openai.test.zsh`: OpenAI provider tests with mocked `curl`.
- `tests/providers/openai_codex.test.zsh`: Codex OAuth provider tests with mocked `curl`.
- `README.md`, `INSTALL.md`, `TROUBLESHOOTING.md`: public docs that must be updated for provider/auth changes.

Repository invariants from `CLAUDE.md`:

- Implementation is zsh.
- `curl` and `perl` are required.
- `jq` must stay optional.
- Generated commands must land in the prompt before execution.
- Test both `# ...` and `zsh-ai "..."` when behavior changes affect both flows.
- Provider changes need tests and docs.

## User Decisions

The user made these decisions explicitly:

- Use a `zsh-ai` subcommand for Codex OAuth management.
- `zsh-ai` should maintain its own token file at `~/.local/share/zsh-ai/auth.json`.
- Implement only headless device-code login. Do not depend on a graphical environment or browser callback server.
- Prefer direct backend calls over shelling out to `codex exec`.

## High-Level Goal

Support this configuration:

```zsh
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_AUTH="codex"
export ZSH_AI_OPENAI_MODEL="gpt-5.4-mini"
```

Then allow users to authenticate with:

```zsh
zsh-ai-codex login
```

After authentication, both flows should use ChatGPT/Codex OAuth automatically:

```zsh
zsh-ai "list files sorted by size"
# list files sorted by size
```

Existing API-key usage must keep working:

```zsh
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_API_KEY="..."
unset ZSH_AI_OPENAI_AUTH
```

## Non-Goals

- Do not implement `codex exec` integration.
- Do not depend on the Codex CLI, Codex auth storage, or Codex keyring storage.
- Do not implement browser callback login on ports `1455` or `1457`.
- Do not require `jq`.
- Do not change default OpenAI API-key behavior.
- Do not auto-run generated shell commands.
- Do not print access tokens, refresh tokens, authorization codes, or raw JWTs.

## External Protocol References

These details were found in `openai/codex` and `anomalyco/opencode` source code during investigation.

Important constants:

- OAuth issuer: `https://auth.openai.com`
- OAuth client ID: `app_EMoamEEZ73f0CkXaXp7hrann`
- Codex backend endpoint: `https://chatgpt.com/backend-api/codex/responses`
- Device-code verification URL shown by Codex/OpenAI UX is expected to be under `https://auth.openai.com`.
- OpenCode constant for Codex endpoint: `https://chatgpt.com/backend-api/codex/responses`
- Codex base URL constant: `https://chatgpt.com/backend-api/codex`

Expected auth headers:

```text
Authorization: Bearer <access_token>
ChatGPT-Account-ID: <account_id>
```

Potential additional parity header for FedRAMP accounts:

```text
X-OpenAI-Fedramp: true
```

Do not implement FedRAMP support unless it falls out naturally from stored metadata. It is acceptable to leave it as a follow-up.

Relevant upstream files to re-check if needed:

- `openai/codex/codex-rs/model-provider-info/src/lib.rs`
- `openai/codex/codex-rs/model-provider/src/bearer_auth_provider.rs`
- `openai/codex/codex-rs/login/src/device_code_auth.rs`
- `openai/codex/codex-rs/login/src/auth/manager.rs`
- `openai/codex/codex-rs/login/src/server.rs`
- `anomalyco/opencode/packages/opencode/src/plugin/openai/codex.ts`
- `anomalyco/opencode/packages/core/src/plugin/provider/openai-auth.ts`
- `anomalyco/opencode/packages/llm/src/protocols/openai-responses.ts`

## Assumptions

Make these assumptions explicit in implementation comments or docs only where useful. Do not over-comment code.

1. `ZSH_AI_OPENAI_AUTH` controls auth behavior for `ZSH_AI_PROVIDER=openai`.
2. `ZSH_AI_OPENAI_AUTH=api_key` is the default and preserves existing behavior.
3. `ZSH_AI_OPENAI_AUTH=codex` uses ChatGPT/Codex OAuth and the Codex Responses backend.
4. The auth file is zsh-ai-owned and independent from Codex CLI storage.
5. The default auth file path is exactly `~/.local/share/zsh-ai/auth.json`.
6. The auth file may be overridden by `ZSH_AI_CODEX_AUTH_FILE` for tests and advanced users.
7. `jq` may be present but cannot be required.
8. `perl` can be used for JSON extraction fallbacks because the project already requires it.
9. Token refresh should happen before a request if the token expires within 5 minutes.
10. A `401` from the Codex backend should trigger one refresh-and-retry attempt.
11. If refresh fails, users should be told to run `zsh-ai-codex login` again.
12. The endpoint is unofficial relative to public OpenAI API-key usage; isolate it behind `ZSH_AI_OPENAI_AUTH=codex`.
13. Because OpenCode and Codex use Responses API shape for this backend, zsh-ai should not send the current Chat Completions payload when using Codex auth.

## Public Interface

### Configuration

Add these variables in `lib/config.zsh`:

```zsh
: ${ZSH_AI_OPENAI_AUTH:="api_key"}
: ${ZSH_AI_CODEX_AUTH_FILE:="$HOME/.local/share/zsh-ai/auth.json"}
: ${ZSH_AI_CODEX_ISSUER:="https://auth.openai.com"}
: ${ZSH_AI_CODEX_ENDPOINT:="https://chatgpt.com/backend-api/codex/responses"}
```

Use a private/internal constant for the OAuth client ID unless tests require overriding it:

```zsh
_ZSH_AI_CODEX_CLIENT_ID="app_EMoamEEZ73f0CkXaXp7hrann"
```

If an override is needed for tests, prefer a private testable variable such as `_ZSH_AI_CODEX_CLIENT_ID`, not prominent public docs.

### Subcommands

Implement these subcommands through the `zsh-ai-codex` helper function in `lib/utils.zsh`:

```zsh
zsh-ai-codex login
zsh-ai-codex logout
zsh-ai-codex status
```

Subcommand behavior:

- `zsh-ai-codex login`: run headless device-code OAuth login and write auth file.
- `zsh-ai-codex logout`: delete auth file if present and report signed out.
- `zsh-ai-codex status`: report signed-in or signed-out. If signed in, show account ID if known and approximate expiry. Never print secrets.

Invalid subcommands should print concise usage and return non-zero.

Keep existing command generation behavior for `zsh-ai "prompt"`.

## Auth File Format

Default path:

```text
~/.local/share/zsh-ai/auth.json
```

Recommended JSON shape:

```json
{
  "type": "codex",
  "access_token": "...",
  "refresh_token": "...",
  "expires_at": 1234567890000,
  "account_id": "..."
}
```

Notes:

- `expires_at` should be Unix epoch milliseconds.
- Store `account_id` if it can be extracted.
- It is acceptable for `account_id` to be empty if extraction fails, but requests should include `ChatGPT-Account-ID` when available.
- Consider storing `id_token` only if needed for account extraction. Prefer not storing it if account ID can be extracted during login/refresh.

Filesystem requirements:

- Create parent directory with mode `0700`.
- Write auth file with mode `0600`.
- Avoid temporary files that can be world-readable.
- Do not print token values.

Possible implementation approach:

```zsh
mkdir -p -- "$auth_dir"
chmod 700 -- "$auth_dir"
umask 077
print -r -- "$json" >| "$auth_file"
chmod 600 -- "$auth_file"
```

Use care with zsh quoting and `>|` if `noclobber` may be set.

## Device-Code Login Flow

Implement in zsh using `curl` and JSON parsing helpers.

### Step 1: Create User Code

Request:

```text
POST https://auth.openai.com/api/accounts/deviceauth/usercode
Content-Type: application/json
```

Body:

```json
{"client_id":"app_EMoamEEZ73f0CkXaXp7hrann"}
```

Parse expected fields. Verify exact names from live response or upstream source if needed:

- `device_auth_id`
- `user_code`
- `verification_uri` or `verification_url` if present
- `interval` if present
- `expires_in` if present

Display a terminal-only instruction, for example:

```text
Open this URL on any device: https://auth.openai.com/codex/device
Enter this code: ABCD-EFGH
Waiting for authorization...
```

Prefer using the response-provided verification URL if available. If the response does not include one, use the known Codex device URL from upstream behavior.

### Step 2: Poll for Authorization Code

Request:

```text
POST https://auth.openai.com/api/accounts/deviceauth/token
Content-Type: application/json
```

Expected body, based on prior investigation:

```json
{
  "device_auth_id": "...",
  "user_code": "..."
}
```

Polling behavior:

- Use `interval` from the user-code response, defaulting to a conservative value such as 5 seconds.
- Continue polling for pending authorization responses such as HTTP `403` or `404`, or JSON errors indicating pending authorization.
- Stop after expiration if `expires_in` is available.
- Return non-zero and print a concise failure if polling expires or receives a non-retryable error.

On success, parse:

- `authorization_code`
- `code_verifier`
- Possibly `code_challenge`, though token exchange likely needs only `code_verifier`.

### Step 3: Exchange Authorization Code

Request:

```text
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded
```

Body fields:

```text
grant_type=authorization_code
code=<authorization_code>
redirect_uri=https://auth.openai.com/deviceauth/callback
client_id=app_EMoamEEZ73f0CkXaXp7hrann
code_verifier=<code_verifier>
```

Parse:

- `access_token`
- `refresh_token`
- `expires_in`
- `id_token`, if present and useful for account ID extraction

Compute:

```text
expires_at = current_epoch_ms + expires_in * 1000
```

Then extract `account_id` and write the auth file.

## Token Refresh Flow

Before each Codex request:

1. Load auth file.
2. Parse `access_token`, `refresh_token`, `expires_at`, and `account_id`.
3. If `access_token` or `refresh_token` is missing, fail with `Run zsh-ai-codex login to sign in with ChatGPT/Codex.`
4. If `expires_at` is missing or within 5 minutes, refresh.

Refresh request:

```text
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded
```

Body:

```text
grant_type=refresh_token
refresh_token=<refresh_token>
client_id=app_EMoamEEZ73f0CkXaXp7hrann
```

Persist any returned values:

- `access_token`
- `refresh_token`, falling back to the old refresh token if omitted
- `expires_in`
- `id_token`, only for extraction if needed
- `account_id`, using new token claims if possible and falling back to old stored `account_id`

On refresh failure:

- Do not delete the auth file automatically.
- Print `Run zsh-ai-codex login to sign in again.`
- Return non-zero.

On Codex backend `401`:

- Refresh once.
- Retry the request once.
- If retry fails or refresh fails, return non-zero with a concise error.

## Account ID Extraction

Extract account ID from JWT payloads, preferring `id_token`, then `access_token`.

Claims to support:

- `chatgpt_account_id`
- `https://api.openai.com/auth.chatgpt_account_id`
- Namespaced object shape: `"https://api.openai.com/auth": { "chatgpt_account_id": "..." }`
- Fallback to first organization ID if present, e.g. `organizations[0].id`

Implementation guidance:

- JWT payload is the second dot-separated segment.
- Convert base64url to standard base64.
- Add padding as needed.
- Decode with a tool available on common systems. Prefer `perl` if possible. If using `base64`, account for GNU/BSD differences only if relevant to this repo's platform assumptions.
- Parse decoded JSON with `jq` if present, otherwise with `perl`.

Do not fail login just because account ID extraction fails. Store an empty `account_id` and omit the `ChatGPT-Account-ID` header if missing.

## Codex Request Flow

When `ZSH_AI_PROVIDER=openai` and `ZSH_AI_OPENAI_AUTH=codex`, branch away from the current Chat Completions payload in `lib/providers/openai.zsh`.

Endpoint:

```text
${ZSH_AI_CODEX_ENDPOINT:-https://chatgpt.com/backend-api/codex/responses}
```

Required headers:

```text
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
User-Agent: zsh-ai
originator: zsh-ai
```

Conditional header:

```text
ChatGPT-Account-ID: <account_id>
```

Use Responses API shape, not Chat Completions:

```json
{
  "model": "gpt-5.4-mini",
  "instructions": "<system prompt with context>",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "<user query>"
        }
      ]
    }
  ],
  "store": false,
  "stream": true
}
```

Use streaming responses for zsh-ai Codex mode. The Codex backend rejects non-streaming requests with `stream must be set to true`.

Use the existing prompt construction from `lib/utils.zsh` where possible. If the existing provider receives a single combined prompt string, preserve behavior by placing that prompt in either `instructions` or `input` consistently. Prefer:

- `instructions`: zsh-ai system instruction and context.
- `input`: the user request.

If the current provider boundary only passes a combined prompt, use that combined prompt as `input[0].content[0].text` for the first iteration. Do not do a large refactor unless needed.

JSON construction:

- Reuse existing escaping helpers if available.
- Keep JSON construction robust for quotes, backslashes, and newlines.
- If existing provider manually escapes JSON, extend it carefully and test with quoted prompts.

## Response Parsing

Use streaming Responses output. Parse Server-Sent Events and combine the streamed text into one shell command before returning it to the widget or `zsh-ai` command.

Parser requirements:

- Read Server-Sent Events `data:` lines.
- Concatenate `response.output_text.delta` values.
- Prefer `response.output_text.done` text when present.
- Prefer top-level `output_text` if present and non-empty.
- Otherwise extract text from nested Responses output shapes such as `output[].content[].text`.
- Detect error objects and failed/incomplete response statuses when present.
- If no output text is found, return an error similar to existing provider behavior.
- Preserve current cleanup behavior so the shell command is a single command line inserted into the prompt.

Example responses to support:

```json
{
  "id": "resp_123",
  "output_text": "ls -la"
}
```

```json
{
  "id": "resp_123",
  "output": [
    {
      "type": "message",
      "content": [
        {
          "type": "output_text",
          "text": "ls -la"
        }
      ]
    }
  ]
}
```

Implement parser with `jq` when available and `perl` fallback. Do not require `jq` in tests.

## Suggested Function Layout

Keep API-key/OpenAI-compatible Chat Completions behavior in `lib/providers/openai.zsh`. Keep all Codex OAuth helpers and Codex Responses behavior in `lib/providers/openai_codex.zsh`.

Possible functions:

```zsh
_zsh_ai_openai_auth_mode
_zsh_ai_query_openai_codex
_zsh_ai_codex_auth_file
_zsh_ai_codex_load_auth
_zsh_ai_codex_write_auth
_zsh_ai_codex_refresh_if_needed
_zsh_ai_codex_refresh
_zsh_ai_codex_login
_zsh_ai_codex_logout
_zsh_ai_codex_status
_zsh_ai_codex_extract_account_id
_zsh_ai_codex_parse_response
```

Codex-specific implementation file:

```text
lib/providers/openai_codex.zsh
```

Source it from `zsh-ai.plugin.zsh` near `lib/providers/openai.zsh`. Tests should keep Codex coverage in `tests/providers/openai_codex.test.zsh`.

## Config Validation Changes

In `lib/config.zsh`:

- Validate `ZSH_AI_OPENAI_AUTH` only for OpenAI provider or globally if simpler.
- Accepted values: `api_key`, `codex`.
- Default: `api_key`.
- For `api_key`, preserve existing API-key validation.
- For `codex`, do not require `OPENAI_API_KEY` or `ZSH_AI_OPENAI_API_KEY`.
- Do not require `ZSH_AI_CODEX_AUTH_FILE` to exist during shell/plugin load.

Expected validation behavior:

```zsh
ZSH_AI_PROVIDER=openai ZSH_AI_OPENAI_AUTH=codex
```

should pass even without an API key.

```zsh
ZSH_AI_PROVIDER=openai ZSH_AI_OPENAI_AUTH=bad
```

should fail with a clear error.

## `zsh-ai` Command Changes

Find the current `zsh-ai` function in `lib/utils.zsh`.

Add a helper command next to `zsh-ai`:

```zsh
zsh-ai-codex() {
  case "$1" in
    login) _zsh_ai_codex_login ;;
    logout) _zsh_ai_codex_logout ;;
    status) _zsh_ai_codex_status ;;
    *) print usage; return 1 ;;
  esac
  return $?
}
```

Ensure `zsh-ai-codex login extra` returns non-zero rather than ignoring unexpected args.

Update help/usage if the project has existing help output.

## Error Messages

Use concise messages.

Recommended messages:

- Missing auth file: `Run zsh-ai-codex login to sign in with ChatGPT/Codex.`
- Refresh failed: `Run zsh-ai-codex login to sign in again.`
- Unknown auth mode: `Invalid ZSH_AI_OPENAI_AUTH: <value> (expected api_key or codex)`
- Login polling expired: `Codex login expired. Run zsh-ai-codex login to try again.`
- Login denied/cancelled: `Codex login was not authorized.`

Avoid exposing raw server responses if they may include secrets. It is fine to expose sanitized API error messages.

## Tests To Add Or Update

Run existing tests first if helpful to understand current harness:

```bash
./run-tests.zsh
./run-tests.zsh tests/providers
zsh tests/config.test.zsh
```

### Config Tests

Update `tests/config.test.zsh`:

- `ZSH_AI_OPENAI_AUTH=codex` with `ZSH_AI_PROVIDER=openai` passes without OpenAI API key.
- Default API-key mode still requires an API key when configured against the default OpenAI URL.
- `ZSH_AI_OPENAI_AUTH=api_key` behaves like current behavior.
- Invalid `ZSH_AI_OPENAI_AUTH` fails.
- Defaults include `ZSH_AI_CODEX_AUTH_FILE=$HOME/.local/share/zsh-ai/auth.json`.

### Provider Tests

Update or add Codex provider tests under `tests/providers/openai_codex.test.zsh`:

- Codex request uses `ZSH_AI_CODEX_ENDPOINT`.
- Codex request sends `Authorization: Bearer <access_token>`.
- Codex request sends `ChatGPT-Account-ID` when stored.
- Codex request omits `ChatGPT-Account-ID` when account ID is empty.
- Codex request uses Responses payload with `instructions`, `input`, `store:false`, `stream:true`, and model.
- Response parser extracts top-level `output_text`.
- Response parser extracts nested `output[].content[].text`.
- Response parser extracts streamed `response.output_text.delta` and `response.output_text.done` events.
- Response parser returns failure on empty response.
- Response parser returns failure on error object, failed status, or incomplete status.
- Expired token triggers refresh before request.
- Fresh token does not trigger refresh.
- Backend `401` triggers one refresh and one retry.
- Refresh failure prompts re-login and returns non-zero.
- Parser works when `jq` is unavailable. Tests may manipulate `PATH` or function stubs depending on current harness style.

### Subcommand Tests

Add tests where the current harness supports command-level tests:

- `zsh-ai-codex logout` deletes `ZSH_AI_CODEX_AUTH_FILE`.
- `zsh-ai-codex logout` succeeds or gives friendly output when already signed out.
- `zsh-ai-codex status` reports signed out when file missing.
- `zsh-ai-codex status` reports signed in without printing `access_token` or `refresh_token`.
- `zsh-ai-codex login` calls mocked user-code endpoint, mocked polling endpoint, mocked token endpoint, then writes auth JSON with `0600` permissions.

If login end-to-end tests are too heavy, at minimum test the lower-level login helper with mocked `curl` responses and a temporary `ZSH_AI_CODEX_AUTH_FILE`.

## Documentation Updates

Update `README.md`:

- Add a concise section for ChatGPT/Codex OAuth under providers or OpenAI usage.
- Show `ZSH_AI_OPENAI_AUTH=codex` config.
- Show `zsh-ai-codex login`, `status`, and `logout`.
- State that auth file is stored at `~/.local/share/zsh-ai/auth.json` with restricted permissions.
- State that generated commands still land in the prompt before execution.

Update `INSTALL.md`:

- Add setup instructions for ChatGPT/Codex OAuth.
- Make clear that no OpenAI API key is required for `ZSH_AI_OPENAI_AUTH=codex`.
- Explain that this uses terminal device-code login and can be completed from another device.

Update `TROUBLESHOOTING.md`:

- Missing auth file: run `zsh-ai-codex login`.
- Expired/revoked token: run `zsh-ai-codex login` again.
- Permission issues for `~/.local/share/zsh-ai/auth.json`.
- `jq` is optional; if parsing fails, include basic troubleshooting without requiring `jq`.

## Verification Commands

Run these before finishing:

```bash
./run-tests.zsh
./run-tests.zsh tests/providers
zsh tests/config.test.zsh
```

Manual smoke tests, if real credentials are available:

```zsh
export ZSH_AI_PROVIDER="openai"
export ZSH_AI_OPENAI_AUTH="codex"
zsh-ai-codex status
zsh-ai-codex login
zsh-ai-codex status
zsh-ai "print the current directory"
```

Also test the widget path manually if possible:

```zsh
# print the current directory
```

The command should be inserted into the prompt, not executed automatically.

## Implementation Order

Recommended sequence:

1. Read current `lib/config.zsh`, `lib/utils.zsh`, `lib/providers/openai.zsh`, and relevant tests.
2. Add config defaults and validation for `ZSH_AI_OPENAI_AUTH` and Codex settings.
3. Add auth-file read/write helpers with tests.
4. Add token parsing and account ID extraction helpers with tests.
5. Add refresh helper with mocked `curl` tests.
6. Add Codex Responses request branch in OpenAI provider with mocked `curl` tests.
7. Add streaming Responses parser with non-streaming fallback coverage.
8. Add `zsh-ai-codex login/logout/status` helper.
9. Add login flow tests with mocked `curl` if practical.
10. Update README, INSTALL, and TROUBLESHOOTING.
11. Run full tests and fix regressions.

## Edge Cases To Handle

- Auth file missing.
- Auth file exists but is malformed.
- Auth file missing `refresh_token`.
- `expires_at` missing or non-numeric.
- Token refresh returns no new `refresh_token`.
- Account ID cannot be extracted.
- Codex backend returns `401` once then succeeds after refresh.
- Codex backend returns repeated `401` after refresh.
- Response has top-level `output_text`.
- Response has only nested `output[].content[].text`.
- Response has failed or incomplete status with an error object.
- User prompt includes quotes, backslashes, dollar signs, and newlines.
- `noclobber` is enabled in zsh.
- `jq` is absent.
- `ZSH_AI_CODEX_AUTH_FILE` points to a path whose parent does not exist.

## Security Notes

- Never log or print tokens.
- Do not include raw token JSON in error messages.
- Use `0600` for auth file and `0700` for the parent directory.
- Prefer zsh local variables for token values.
- Avoid putting tokens in command arguments where possible, but `curl -H "Authorization: Bearer ..."` is consistent with the current provider style. Do not add verbose logging around it.
- Be careful in tests not to assert or print realistic token values.

## Completion Criteria

The work is complete when:

- Existing API-key OpenAI behavior still works and tests pass.
- `ZSH_AI_OPENAI_AUTH=codex` does not require an API key.
- `zsh-ai-codex login/logout/status` exist and behave as documented.
- Codex auth tokens are stored in `~/.local/share/zsh-ai/auth.json` by default.
- Codex requests use the Codex Responses endpoint and bearer OAuth token.
- Expired tokens refresh automatically.
- `401` responses refresh and retry once.
- Streaming Responses output is parsed into a single shell command.
- Docs explain setup and troubleshooting.
- `./run-tests.zsh`, `./run-tests.zsh tests/providers`, and `zsh tests/config.test.zsh` pass, or any failures are documented with clear reasons.
