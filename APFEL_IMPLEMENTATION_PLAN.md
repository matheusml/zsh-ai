# Apfel provider implementation plan

Repository: `zsh-ai-public`  
Branch: `rg/add-mac-apfel-support`  
Status: Implementation and approved acceptance complete.

## 1. Goal and scope

Add `ZSH_AI_PROVIDER="apfel"` to the existing plugin. On a supported Mac, users can generate commands with Apple's on-device model without a hosted AI account or API key.

Preserve both existing entry points:

- Type `# show git status`, then press Enter.
- Run `zsh-ai "show git status"`.

Both must put the suggestion at the prompt for review. Neither may execute it. A failed inline request must restore the original input.

The existing no-argument `zsh-ai` usage output must show how to select Apfel, install and start it, and find its platform requirements. This guidance must be discoverable before Apfel is selected. When selected, show the active Apfel model and endpoint. Keep the existing no-argument exit status; do not treat usage output as a generation request.

Keep Anthropic as the default. Do not auto-select Apfel, change other providers, add a provider framework, rewrite the widget, or add automatic fallback to a hosted service. Apfel is an optional user-installed backend, not a new dependency for all users.

## 2. Findings from the current code

| Location | Current behavior | Required change |
| --- | --- | --- |
| `lib/config.zsh` | Defines settings and validates the provider name and provider-specific configuration. | Register Apfel and its settings. |
| `zsh-ai.plugin.zsh` | Sources each provider module before utilities and widget initialization. | Source the new provider module. |
| `lib/utils.zsh` | `_zsh_ai_query` dispatches requests; `zsh-ai` also shows provider information. | Add Apfel dispatch, setup guidance, and active model/endpoint information. |
| `lib/context.zsh` | Collects directory, filenames, project type, Git state, and OS. | Reuse without changes. |
| `lib/utils.zsh` | `_zsh_ai_get_system_prompt` adds common command rules and `ZSH_AI_PROMPT_EXTEND`. | Reuse without changing existing provider prompts. |
| `lib/widget.zsh` and `zsh-ai` | Capture provider stdout, suppress its stderr, and check exit status. | Preserve this contract. Provider errors must remain visible through stdout. |
| `run-tests.zsh` | Discovers `*.test.zsh` recursively. | New provider tests need no runner registration. |
| `.github/workflows/test.yml` | Runs the suite on Ubuntu. | Keep automated tests independent of Apple hardware and live inference. |

The contribution guide requires small PRs, zsh 5.0+ support, optional `jq`, existing test helpers, provider error coverage, updated configuration documentation, and manual checks of both entry points. Keep this PR limited to one provider. If maintainers classify it as a larger feature, discuss it in an issue before submitting the PR. This plan does not authorize publishing an issue or PR.

## 3. Integration decision

### Use Apfel's local HTTP server

Implement a dedicated provider against `/v1/chat/completions`. Apfel supports this API and exposes `finish_reason`, which lets the plugin reject truncated command suggestions.

The direct CLI was considered first because it avoids a background service. Current upstream CLI code returns success for truncated output and reports truncation on stderr. Its JSON envelope does not include `finish_reason`. Parsing a warning sentence would make the integration depend on diagnostic wording. Use the HTTP API instead.

Do not route Apfel through `_zsh_ai_query_openai` by temporarily changing OpenAI variables. That function has OpenAI-specific token parameters, reasoning settings, authentication, and errors. A small provider module is consistent with this repository and keeps those settings independent. Do not refactor all HTTP providers in this PR.

Tradeoff: users must start Apfel once, either in the foreground or through Homebrew services. The plugin must not install software, start services, or make health requests when a shell starts.

### Supported setup

Apfel documents these requirements:

- Apple Silicon, M1 or later.
- macOS 26 or later.
- Apple Intelligence enabled and the on-device model available.
- Apfel installed and its server running.

Use Apfel 1.12.0 as the initial verification baseline, matching the upstream version reviewed for this plan. Document the version actually exercised before release; do not claim support for older releases without checking their API and tool-disabling behavior.

Apple manages model availability. Do not duplicate hardware, OS, language, region, or download-state checks in zsh. A reachable server can still have an unavailable model; report its error at request time.

## 4. User setup and configuration

Document the standard setup:

```zsh
brew install apfel
brew services start apfel
```

Then, before the plugin is sourced in `~/.zshrc`:

```zsh
export ZSH_AI_PROVIDER="apfel"
```

For a temporary foreground server, users can run `apfel --serve` in another terminal instead of enabling a service.

Add only these provider-specific settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| `ZSH_AI_APFEL_URL` | `http://127.0.0.1:11434/v1/chat/completions` | Full chat-completions endpoint; permits a different local port. |
| `ZSH_AI_APFEL_API_KEY` | Unset | Optional bearer token for an Apfel server started with authentication. |
| `ZSH_AI_APFEL_MAX_TOKENS` | `256` | Positive integer output limit. |

Use the fixed model ID `apple-foundationmodel`. Do not add a model-selection variable: Apfel exposes one Apple model. Do not inherit `OPENAI_API_KEY`, `ZSH_AI_OPENAI_API_KEY`, or OpenAI generation settings.

Validate the positive token limit only when Apfel is selected. Accept Apfel without an API key and without an `apfel` executable on the client's PATH; the provider communicates with the configured server. Keep validation free of network requests.

Apfel and Ollama both default to port 11434. Explain the conflict and show this alternative:

```zsh
# In a separate terminal:
apfel --serve --port 11435

# In ~/.zshrc, before loading the plugin:
export ZSH_AI_PROVIDER="apfel"
export ZSH_AI_APFEL_URL="http://127.0.0.1:11435/v1/chat/completions"
```

The local privacy claim applies to a local Apfel endpoint. An explicitly configured remote endpoint sends context to that host; document that distinction. No cloud fallback is allowed.

## 5. Provider behavior

Create `lib/providers/apfel.zsh` with `_zsh_ai_query_apfel` and only the private helpers needed for response handling.

### Request

1. Collect context with `_zsh_ai_build_context`.
2. Build the shared system prompt with `_zsh_ai_get_system_prompt "$context"`.
3. Escape the completed system prompt and user request once for JSON. Do not pre-escape context before passing it to the prompt builder.
4. Send one non-streaming POST request with:
   - `model: "apple-foundationmodel"`;
   - separate system and user messages;
   - `temperature: 0.3`, consistent with existing providers;
   - `max_tokens` from the Apfel setting;
   - `stream: false`;
   - `tool_choice: "none"`.
5. Add a bearer header only when the Apfel-specific key is set.

`tool_choice: "none"` is required. Apfel servers can have MCP tools attached, including remote tools. Upstream documents that this setting hides tools and prevents automatic MCP execution. Do not send tool definitions, enable permissive guardrails, or enable retries.

Use `curl` with separate handling of transport status, HTTP status, and response body. Set bounded connection and request times, initially 5 seconds and 90 seconds respectively. Verify the request deadline against cold local inference before release. Do not add a preliminary health call to every request. Connect directly rather than allowing proxy environment variables to route the local request elsewhere, and do not follow redirects.

### Response

Accept only a successful HTTP response with a valid completion object, a nonempty string at `choices[0].message.content`, and `finish_reason: "stop"`. Reject tool calls and all other completion reasons. In particular, an HTTP 200 response with `finish_reason: "length"` must fail without inserting partial content.

Keep `jq` optional. Use `jq` when available and Perl's core `JSON::PP` decoder otherwise. Perl is already a project dependency; do not require CPAN installation. Verify the core module on supported execution environments. Use an actual JSON decoder, not regular expressions, so quotes, backslashes, Unicode, and escaped newlines retain their meaning.

For valid content:

- Remove surrounding whitespace and, if present, one enclosing Markdown code fence.
- Preserve shell quoting, backslashes, and internal whitespace.
- Reject remaining multiline content rather than deleting newlines and changing command meaning.
- Return only the command text on stdout with status 0.

Do not use `eval`, execute the suggestion for validation, or describe syntactically valid output as safe. Review before execution remains necessary.

### Failures

Return nonzero and print an `Error:`-prefixed message on stdout, matching the existing callers. Do not print a partial command alongside an error. Use bounded, plain diagnostics; do not expose credentials, complete request bodies, or raw HTML responses.

Handle these cases:

| Failure | User guidance |
| --- | --- |
| Connection refused | Start Apfel; check the configured port and possible Ollama conflict. |
| Request timeout | Explain that generation timed out; leave retry to the user. |
| Authentication rejected | Check the optional Apfel token against the server configuration. |
| Model unavailable | Check Apple Intelligence and model readiness. |
| Guardrail refusal | Show the refusal as a failure; do not silently relax guardrails. |
| Context overflow | Shorten the request or custom prompt extension. |
| Truncated completion | Explain that the response was incomplete; shorten the request or increase the output limit within the model's context capacity. |
| Rate limit or server error | Report the server failure without automatic retries. |
| Invalid JSON, wrong response shape, empty content, or unsupported completion reason | Report an unusable response without inserting it. |

Use structured server error information where supplied. Avoid duplicating every upstream error code in the plugin. The provider-specific diagnostics must work with the current UI, which discards stderr.

## 6. File changes

| File | Planned change |
| --- | --- |
| `lib/providers/apfel.zsh` | New request, response, and error implementation. |
| `lib/config.zsh` | Apfel settings, accepted provider name, and token-limit validation. |
| `lib/utils.zsh` | Dispatch, discoverable no-argument Apfel setup guidance, and active model/endpoint information. |
| `zsh-ai.plugin.zsh` | Source the new module; correct the provider summary comment if retained. |
| `tests/providers/apfel.test.zsh` | Provider behavior and error regression tests. |
| `tests/config.test.zsh` | Apfel configuration boundaries and lack of API-key requirement. |
| `tests/utils.test.zsh`, `tests/widget.test.zsh` | Extend only where existing coverage does not prove Apfel failure preserves the input and success remains review-only. |
| `tests/test_helper.zsh` | Change only if required for reusable HTTP-status mocks or isolated cleanup. Keep Apfel-only fixtures in the provider test file. |
| `README.md` | Mention the supported-Mac local option and link to setup. |
| `INSTALL.md` | Provider table, setup, requirements, settings, token authentication, and port conflict. Clarify that Apfel has no selectable model. |
| `TROUBLESHOOTING.md` | Missing server, unavailable model, authentication, context, and truncation guidance. |

No changes are planned for context collection, other provider implementations, the test runner, or CI infrastructure. The existing runner should discover the new tests. Keep this plan separate from the upstream feature diff unless the maintainers request a design document.

## 7. Automated verification

Use `tests/test_helper.zsh`, `run_test`, and `finish_tests`. Keep tests deterministic and runnable on Linux without Apfel, network access, Apple Intelligence, or credentials. Restore mocks and environment variables after each case.

Cover consumer-visible behavior:

- Apfel works without any hosted-provider keys; invalid token limits fail configuration.
- A complete response returns the correct command, including shell quotes, backslashes, and Unicode.
- JSON parsing has equivalent behavior with and without `jq`.
- Markdown fences are removed without changing the enclosed command; multiline output is rejected without concatenation.
- Empty, whitespace-only, missing, null, non-string, and malformed content are rejected.
- Truncated output is rejected even when HTTP status and transport exit status indicate success.
- Tool-call responses are rejected.
- Connection errors, timeouts, authentication errors, context overflow, model unavailability, guardrail refusal, and server failures return usable errors rather than suggestions.
- Error messages cannot become command text, and a failed inline request preserves the user's input.

Use a throwaway local HTTP server for an integration smoke check of the real `curl` path. Observe the actual JSON request, HTTP-status handling, optional authentication, no inherited OpenAI key, and `tool_choice: "none"`. Include request text with quotes, newlines, dollar signs, backticks, and a leading hyphen. These characters must be transmitted as data, not interpreted by the shell.

After the implementation and test changes are complete, run the full suite once:

```zsh
./run-tests.zsh
```

For a focused failure during final verification, the contribution guide also supports:

```zsh
./run-tests.zsh tests/providers
zsh tests/config.test.zsh
```

Do not add permanent tests that only inspect source text, count dispatch calls, or repeat the implementation's literals.

## 8. Real-Mac acceptance checks

Automated fixtures do not prove Apple model behavior. On a supported Mac with Apfel installed:

1. Record the Apfel version, macOS version, architecture, and model availability. Do not publish personal paths or keys.
2. Start a loopback-only Apfel server. Confirm the configured port belongs to Apfel, not Ollama.
3. Open interactive zsh, select Apfel, and source the branch's plugin.
4. Exercise both `# show git status` and `zsh-ai "show git status"`. Observe that each produces an editable suggestion without execution.
5. Try a small set of macOS shell tasks: list files, find recently modified files, find large files, identify a listening process, and handle a filename containing spaces. Check syntax and BSD/macOS utility compatibility by inspection and safe use in a disposable directory.
6. Exercise `ZSH_AI_PROMPT_EXTEND`, a custom trigger, and the disabled comment hook without changing their existing behavior.
7. Stop the server and repeat both entry points. Confirm visible guidance, no inserted error text, and preserved inline input.
8. Force a small output limit with a request that needs a longer response. Confirm an incomplete response is rejected rather than offered for execution.
9. Verify `tool_choice: "none"` against a harmless recording MCP fixture on a test server. Confirm no tool invocation occurs. Do not attach real tools with side effects.
10. Repeat a successful and failed request without `jq`.
11. Check Ctrl-C during a request. Confirm the prompt remains usable and no late suggestion appears. Do not claim cancellation behavior that was not exercised.
12. Measure plugin load time with another provider and with Apfel selected, with the server both running and stopped. Confirm loading does not contact the server. Record cold and warm request latency separately; do not promise a speed improvement without measurements.

The planning environment reports macOS 26.6.2 on arm64, but `apfel` was not found on PATH. Apple Intelligence readiness has not been established. No live inference or plugin test suite was run for this plan. Installing and validating Apfel belongs to implementation verification.

## 9. Implementation progress checklist

Mark an item complete only after its result is observed. Record verification commands, exit status, and relevant output with the implementation notes. A mocked response does not complete a real-Apfel item.

### Understand the current state

- [x] Confirm the active branch is `rg/add-mac-apfel-support` and identify existing local changes before editing.
- [x] Read the contribution guide and trace configuration, provider loading, dispatch, prompt construction, and both command-entry paths.
- [x] Record the current test result and distinguish existing failures from changes introduced by this feature.
- [x] Record macOS, architecture, Apfel version, and Apple Intelligence/model availability.
- [x] Verify the real Apfel HTTP contract: successful generation, structured errors, truncation status, and `tool_choice: "none"`.

### Implement the provider and usage guidance

- [x] Add Apfel settings and configuration validation without changing the default provider.
- [x] Add the provider module and connect loading and dispatch.
- [x] Implement bounded HTTP requests, Apfel-only authentication, and disabled tool use.
- [x] Implement correct JSON parsing with and without `jq`.
- [x] Reject incomplete, empty, malformed, multiline, and tool-call responses without offering them as commands.
- [x] Show Apfel installation, service startup, provider selection, and requirements in `zsh-ai` usage output.
- [x] Show the active Apfel model and endpoint when Apfel is selected.

### Unit and local integration tests

- [x] Add the behavior and error cases in section 7 using the existing test helpers.
- [x] Run the focused provider and configuration tests; record their exit status.
- [x] Run the full suite after implementation; resolve regressions.
- [x] Exercise the real `curl` path against a controlled local HTTP fixture, including request escaping, authentication isolation, and HTTP failures.
- [x] Confirm automated fixtures require no Apfel server or binary. Linux execution is deferred by user choice because Apfel is unsupported there.

### End-to-end tests with real Apfel

- [x] Start a dedicated loopback Apfel server and verify its health and model identity.
- [x] Run the live plugin smoke command in section 10 with `ZSH_AI_PROVIDER=apfel`, without provider or transport mocks.
- [x] Run `zsh-ai` with no arguments and confirm the Apfel setup instructions are visible.
- [x] Run `zsh-ai "show git status"` in interactive zsh; inspect the suggested command without executing it.
- [x] Type `# show git status` and press Enter; confirm an editable suggestion appears and does not run automatically.
- [x] Review and run a harmless generated command in a disposable directory; confirm the requested result.
- [x] Stop the dedicated server and repeat both entry points; confirm visible errors and preserved inline input.
- [x] Restart the server and prove truncated output is rejected, including HTTP 200 responses with `finish_reason: "length"`.
- [x] Verify a harmless recording MCP fixture receives no tool invocation.
- [x] Repeat real successful and failed requests without `jq`.
- [x] Complete the prompt-extension, trigger, cancellation, and load/latency checks in section 8.

### Documentation and completion evidence

- [x] Update `README.md`, `INSTALL.md`, and `TROUBLESHOOTING.md` with the verified setup and limitations.
- [x] Record unit-test, local integration, and real-Apfel results separately. Name any incomplete check.
- [x] Stop test-only services and remove temporary verification files.
- [x] Prepare the focused PR description without publishing it.
- [x] Confirm every release criterion in section 11 is met before marking the feature done.

## 10. Critical local end-to-end commands

These commands are the implementation acceptance procedure, not results already obtained. Run repository-relative commands from the `zsh-ai-public` root. The provider must be implemented before the plugin smoke check can pass.

### A. Check requirements and run unit tests

```zsh
git branch --show-current
zsh --version
sw_vers -productVersion
uname -m
command -v apfel
apfel --version
apfel --model-info

# After adding the provider tests:
zsh tests/providers/apfel.test.zsh
zsh tests/config.test.zsh
./run-tests.zsh
```

Expected: the requested branch is active, the Mac meets Apfel requirements, the model is available, and each test command exits 0. Run commands separately so a later success cannot hide an earlier failure. Install Apfel with `brew install apfel` if it is missing.

### B. Start a dedicated real server

In terminal A, use a separate port to avoid the normal Apfel/Ollama port:

```zsh
env -u APFEL_MCP -u APFEL_TOKEN -u APFEL_DEBUG \
  apfel --serve --host 127.0.0.1 --port 11435
```

Leave this terminal open. If the port is occupied, choose another unused port and change every test URL accordingly. Do not stop an unrelated service. This test server has no configured MCP tools or authentication; test optional authentication and tool disabling separately.

In terminal B:

```zsh
curl --noproxy '*' --fail --silent --show-error \
  --connect-timeout 5 --max-time 10 \
  http://127.0.0.1:11435/health

curl --noproxy '*' --fail --silent --show-error \
  --connect-timeout 5 --max-time 10 \
  http://127.0.0.1:11435/v1/models
```

Expected: both requests succeed, health indicates model availability, and the model list includes `apple-foundationmodel`. A listening port alone is not proof that inference works.

### C. Exercise the plugin against real Apfel

Run from the repository root in terminal B:

```zsh
env -u ZSH_AI_APFEL_API_KEY \
  ZSH_AI_PROVIDER=apfel \
  ZSH_AI_APFEL_URL=http://127.0.0.1:11435/v1/chat/completions \
  ZSH_AI_APFEL_MAX_TOKENS=256 \
  ZSH_AI_COMMENT_HOOK=false \
  zsh -f <<'ZSH'
source ./zsh-ai.plugin.zsh
_zsh_ai_validate_config || exit 1
[[ "$ZSH_AI_PROVIDER" == apfel ]] || exit 1

suggestion=$(_zsh_ai_query "Generate one safe zsh command that prints exactly APFEL_SMOKE_OK. Output only the command; do not execute it.")
result=$?
if (( result != 0 )); then
    print -r -- "$suggestion"
    exit 1
fi
if [[ -z "${suggestion//[[:space:]]/}" || "$suggestion" == Error:* ]]; then
    print -u2 -- "FAIL: no usable Apfel suggestion"
    exit 1
fi
print -r -- "$suggestion" | zsh -f -n || exit 1
print -r -- "Apfel suggestion: $suggestion"
print -r -- "PASS: live provider request and shell syntax check"
ZSH
```

Expected: exit 0 and a harmless command that prints `APFEL_SMOKE_OK`. Inspect its meaning; the syntax check alone cannot prove correctness or safety. This command loads the actual plugin, uses its dispatch and context construction, and reaches real Apfel. It does not mock the provider, call a hosted fallback, or execute generated text. It also does not replace the interactive checks below.

### D. Verify usage guidance and both user entry points

From the repository root, start a clean interactive shell in terminal B:

```zsh
zsh -f
export ZSH_AI_PROVIDER=apfel
export ZSH_AI_APFEL_URL=http://127.0.0.1:11435/v1/chat/completions
export ZSH_AI_APFEL_MAX_TOKENS=256
unset ZSH_AI_APFEL_API_KEY
unset ZSH_AI_COMMENT_HOOK ZSH_AI_TRIGGER
source ./zsh-ai.plugin.zsh
zsh-ai
```

Expected usage output includes `brew install apfel`, `brew services start apfel`, `export ZSH_AI_PROVIDER="apfel"`, supported-Mac requirements or their documentation link, and the active model and test endpoint. The existing no-argument status 1 is expected, not an inference failure.

Then run:

```zsh
zsh-ai "show git status"
```

Inspect the proposed command at the next prompt. Do not press Enter to execute it; press Ctrl-C to clear it. Then type this line manually and press Enter once:

```zsh
# show git status
```

Expected: the description becomes a command such as `git status`. It remains editable and has not run. Clear it with Ctrl-C.

For a controlled execution check:

```zsh
test_dir=$(mktemp -d)
cd "$test_dir"
zsh-ai "Print exactly APFEL_E2E_OK without creating or changing any files"
```

Inspect the suggestion. Execute it only if it is a harmless print command matching the request. Expected output is `APFEL_E2E_OK`. If the suggestion is incorrect, record a failure rather than editing it into a passing result. Clear the prompt, return with `cd -`, and remove the empty fixture directory with `rmdir "$test_dir"`.

### E. Verify service failure and incomplete output

Press Ctrl-C in terminal A to stop only the dedicated test server. In terminal B, repeat `zsh-ai "show git status"` and the manually typed `# show git status` request. Expected: both show a connection error, no command is offered, and the inline request is restored. Restart terminal A with the same server command.

In the interactive shell:

```zsh
export ZSH_AI_APFEL_MAX_TOKENS=1
zsh-ai "Find regular files under the current directory larger than 100 megabytes and modified in the last seven days"
```

Expected when Apfel reports `finish_reason: "length"`: an incomplete-response error and no suggested command. If this request does not reach the limit, do not mark truncation as tested. Capture the real API completion reason and choose a request that does reach it. The deterministic provider regression must also cover a truncated HTTP 200 response.

Restore the normal limit:

```zsh
export ZSH_AI_APFEL_MAX_TOKENS=256
```

Run the no-`jq` cases in an isolated test environment with `jq` absent from PATH, while retaining zsh, curl, Perl, and the context utilities. Do not rename or remove the user's installed `jq`. Confirm `command -v jq` fails in that environment, then repeat sections C and E.

## 11. Definition of done

All of the following are required:

- [x] `zsh-ai` usage output explains how to use Apfel as a provider; the setup is also documented in the repository.
- [x] Focused provider/configuration tests and the full existing suite pass.
- [x] Local end-to-end verification uses the actual Apfel provider and actual on-device inference, not only mocks or a direct API request.
- [x] Both interactive entry points produce correct, editable suggestions and require a separate user action to execute them.
- [x] The controlled generated-command check produces the requested output after review.
- [x] Server failures preserve user input; truncated or unusable responses never become command suggestions.
- [x] Tool execution stays disabled, and real requests work with and without `jq`.
- [x] Other providers retain their behavior; no hosted fallback or shell-startup network call is introduced.
- [x] Real-Mac evidence records versions, commands, observed results, and failures. Any unmet acceptance check keeps the feature incomplete.

## 12. Implementation evidence

### Automated and local integration

- Baseline before implementation: `./run-tests.zsh` exited 0 with 249 passing tests.
- Final focused checks: `zsh tests/providers/apfel.test.zsh` and `zsh tests/config.test.zsh` each exited 0.
- Final complete suite: `./run-tests.zsh` exited 0 with 263 passing tests.
- The Apfel provider test uses a loopback Perl fixture. It observed escaped request data, `--noproxy '*'`, Apfel-only authentication, HTTP failures, and `tool_choice: "none"` without a live Apfel server. It also covers transport timeouts, authentication, context overflow, guardrail refusal, rate limits, and generic server failures.

### Real Apfel

- Environment: macOS 26.6.2, arm64, zsh 5.9, Apfel 1.12.0, and `apple-foundationmodel` available with a 4096-token context.
- A loopback server on `127.0.0.1:11435` returned healthy status and listed `apple-foundationmodel`.
- Real provider requests succeeded with and without `jq`: `echo "jq-e2e"` with `/usr/bin/jq`, and `echo "zsh-ai-safe"` with `jq` absent. A stopped-server request returned the expected connection error.
- The approved deterministic section-10 smoke returned `echo "APFEL_SMOKE_OK"` with exit 0. It passed `zsh -f -n` and was not executed.
- The interactive `zsh-ai` and `# ` entries each produced editable suggestions without execution. A focused check of both exact `show git status` entries returned editable `git status`; appending and removing `X` in the ZLE buffer proved editability.
- In a disposable directory, the reviewed suggestion `echo APFEL_E2E_OK` produced `APFEL_E2E_OK`. The test directory and temporary server were removed.
- A real HTTP 200 response with `finish_reason: "length"` caused `Error: Apfel returned an incomplete response...` and no suggestion.
- A real prompt-extension request sent `Return exactly: echo APFEL_EXTENSION_OK` in its system message and inserted editable `echo APFEL_EXTENSION_OK` at the prompt.
- With `ZSH_AI_COMMENT_HOOK=false`, plugin sourcing made no curl request and did not register the comment-hook initializer.
- With `ZSH_AI_TRIGGER=,,`, plugin sourcing made no curl request. In an interactive PTY, `# ` remained a normal comment with no provider request and `,,` produced an editable `printf '%s\n' trigger-custom` suggestion without execution.
- Plugin sourcing made no HTTP request with Apfel stopped or running. Source times were 2.78 ms stopped and 1.78 ms running. Real cold and warm requests took 50.56 ms and 46.49 ms; generated commands were not run.
- During a delayed fixture response, Ctrl-C kept the prompt usable and prevented the late `echo late-cancel` suggestion from appearing. A subsequent manually authored `printf CANCEL_OK` ran normally.
- With Apfel attached to a temporary official `@modelcontextprotocol/server-everything` fixture, the plugin sent `tool_choice: "none"`. The fixture saw initialization and tool listing, but zero tool calls.
- The full suite preserved other providers. Source-time recording saw no request, and Apfel tests showed no inherited OpenAI credential or hosted fallback.

### Historical verification notes

- The original working-directory wording failed on three final-code attempts: two guardrail refusals and one multiline response. The user approved the deterministic harmless section-10 request above as the integration smoke criterion.
- Linux portability remains unobserved by user choice. Apfel has no Linux support; the automated fixture has no Apfel dependency.
- An earlier temporary local MCP fixture was rejected before binding. The official fixture later passed.
- An earlier prompt-extension PTY harness accidentally executed `echo APFEL_EXTENSION_OKexport ZSH_AI_TRIGGER=,,`; it made no repository or system change. A later isolated custom-trigger check passed.


## 13. Focused PR description

**Title:** Add the local Apfel provider for Apple Intelligence

**Summary**

- Add `ZSH_AI_PROVIDER=apfel` through Apfel's local OpenAI-compatible endpoint.
- Keep the fixed `apple-foundationmodel`, optional Apfel-only bearer token, bounded direct requests, and `tool_choice: "none"`.
- Reject empty, malformed, multiline, tool-call, and incomplete responses.
- Add configuration, documentation, usage guidance, and Linux-safe provider tests.

**Verification**

- Focused Apfel and configuration tests passed.
- Full suite passed: 263 tests.
- Real Apfel verification covered setup guidance, both command entries, review-only behavior, a reviewed harmless command, server failure, truncation, `jq`/no-`jq`, cancellation, and MCP tool suppression.

**Known verification variance**

The exact section-10 working-directory wording received a guardrail refusal or multiline model response after the final parser change. Equivalent live plugin requests succeeded, including with `jq` and without it; rejected multiline output is the intended provider behavior.

## Sources

- [zsh-ai contribution guide](https://github.com/matheusml/zsh-ai/blob/main/CONTRIBUTING.md)
- [Apfel requirements, API compatibility, and limitations](https://github.com/Arthur-Ficial/apfel)
- [Apfel CLI output and truncation handling](https://github.com/Arthur-Ficial/apfel/blob/main/Sources/CLI.swift)
- [Apfel CLI reference](https://github.com/Arthur-Ficial/apfel/blob/main/docs/cli-reference.md)
- [Apfel background service](https://github.com/Arthur-Ficial/apfel/blob/main/docs/background-service.md)
- [Apfel server security](https://github.com/Arthur-Ficial/apfel/blob/main/docs/server-security.md)
- [Apfel tool-choice enforcement](https://github.com/Arthur-Ficial/apfel/blob/main/docs/tool-calling-guide.md)
