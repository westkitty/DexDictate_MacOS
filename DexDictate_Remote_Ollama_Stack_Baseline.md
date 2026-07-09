# DexDictate Remote Ollama Stack Baseline

## 1. Purpose

DexDictate must support a local-first remote inference setup where the client Mac running the app does not run the heavy model locally. Instead, it forwards transcription, smart post-processing, and summary requests to a remote inference Mac or home server running Ollama. 

- **No Agent Framework:** The implementation will use direct, standard OpenAI-compatible `/v1` HTTP requests without invoking agent frameworks.
- **Client machine (MacBook):** Does not run the model. It captures speech and dispatches API requests.
- **Remote inference machine (BigMac):** Runs Ollama locally, hosts the weights, and executes inference on its GPU.
- **OpenAI-Compatible endpoint:** Requests are sent using standard `/v1/chat/completions` JSON payloads.

## 2. Andrew's Current Stack

For developer Andrew, the setup maps to specific machines:
- **Client machine:** MacBook
- **Remote inference machine:** BigMac (accessible via network hostnames/IPs e.g., `westcat` or Tailscale IP)
- **Ollama Listening on BigMac:** `http://127.0.0.1:11434`
- **OpenAI-Compatible base URL on BigMac:** `http://127.0.0.1:11434/v1`
- **MacBook Tunnel Endpoint:** `http://127.0.0.1:11435/v1`
- **localhost / 127.0.0.1 Distinction:** 
  - `127.0.0.1:11434` on the MacBook points to the MacBook itself (which does not run the model).
  - `127.0.0.1:11434` on BigMac points to Ollama on BigMac.
  - Therefore, software running on the MacBook must route requests through the local port `11435` which is mapped via SSH tunnel to BigMac's `11434`.

### Verification Commands from MacBook:

1. **Verify Ollama Model Connectivity:**
   ```bash
   curl -s http://127.0.0.1:11435/v1/models
   ```
   *Expected Result:* JSON payload containing the list of installed Ollama models on BigMac.

2. **Verify Inference Execution:**
   ```bash
   curl -s http://127.0.0.1:11435/v1/chat/completions \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "hermesagent:latest",
       "messages": [{"role": "user", "content": "Reply with OK only."}],
       "stream": false
     }'
   ```
   *Expected Result:* JSON completions payload returning `"OK"`. Note: replace `hermesagent:latest` with the actual active model installed on BigMac.

## 3. Generic User Setup

The app must be generalized for any user who wants to forward inference to a home server:
- **Client Mac:** Mac running DexDictate.
- **Remote Inference Server:** Server running Ollama locally on port 11434.
- **SSH Tunnel Port:** An unused local port on the Client Mac (defaulting to `11435` to avoid port collisions with any local Ollama instances on `11434`).
- **SSH Tunnel Command:**
  ```bash
  ssh -N -L <LOCAL_TUNNEL_PORT>:127.0.0.1:11434 <REMOTE_USER>@<REMOTE_HOST>
  ```
  - `<LOCAL_TUNNEL_PORT>`: Client-side local port (e.g. `11435`).
  - `<REMOTE_USER>`: Username on the remote machine.
  - `<REMOTE_HOST>`: IP address or hostname of the remote machine (e.g. over Tailscale).
  - `127.0.0.1` inside the tunnel command tells the remote machine to forward connection to its own localhost on port `11434`.

### Generic Settings Example:
- **Provider Type:** OpenAI-Compatible / Local
- **Base URL:** `http://127.0.0.1:<LOCAL_TUNNEL_PORT>/v1` (e.g., `http://127.0.0.1:11435/v1`)
- **API Key:** `ollama` (placeholder for local security bypass)
- **Model:** User-configured model name installed on the remote machine (e.g. `llama3`, `mistral`).

## 4. Product Requirements for Future DexDictate Provider UI

When the Ollama provider UI is added, it must respect these requirements:
1. **Configurable Base URL:** Do not hard-code `11434` or `11435`. Allow full string input (e.g., `http://127.0.0.1:11435/v1`).
2. **Configurable Model Name:** Text field for entering the specific model identifier (e.g. `hermesagent:latest`).
3. **API Key Field:** Password field with `ollama` as the default placeholder text.
4. **Provider Label:** "Local / Remote Ollama SSH Tunnel".
5. **Help Text:** Clear documentation within settings explaining:
   - Why `11435` is used on the client machine instead of `11434` to prevent local conflicts.
   - How to configure the SSH tunnel command.
   - The distinction between localhost on client vs. remote host.
6. **Diagnostics Buttons:**
   - **Test Connection:** Queries `/v1/models` using the configured base URL to verify the server is responding.
   - **Test Inference:** Sends a lightweight prompt (`Reply with OK only.`) to verify the model is loaded and ready.
7. **Availability Warnings:**
   - Warn the user if they configure `127.0.0.1:11434` on a client Mac while no local Ollama is detected.
   - Warn if the local tunnel port is unreachable.

## 5. Audit Findings From Current Repo

A detailed review of the `DexDictate` codebase was performed to check for existing support for remote providers:

- **OpenAI-compatible base URLs:** **Missing.** No settings or service file references OpenAI client libraries or base URL configs.
  - *Evidence:* Grep for `openai` or `api` in [AppSettings.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Settings/AppSettings.swift) returns zero active configuration hooks.
- **Local Ollama URLs:** **Missing.** No references to `11434` or `11435`.
  - *Evidence:* Search for `11434` in `Sources/` returned zero matches.
- **Configurable model names:** **Partial.** Custom Whisper GGML models can be imported and named via [WhisperModelCatalog.swift](file:///Users/andrew/DexDictate_MacOS.nosync/Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift), but this catalog is strictly restricted to local whisper.cpp `.bin` files and doesn't support LLMs.
- **Configurable API keys:** **Missing.** No credential store or text input fields for API keys.
- **Remote tunnel endpoints:** **Missing.**
- **Provider test requests:** **Missing.**
- **Hard-coded localhost assumptions:** **Missing.** (No localhost calls exist in product network layer since the only networking is Moonshine/Parakeet downloader hitting `download.moonshine.ai`).
- **Docs or UI text confusing local/remote localhost:** **Missing.** (No documentation currently describes remote LLM setups).

## 6. Risks

1. **Localhost confusion:** If users configure `127.0.0.1:11434` in the app running on the MacBook, it will fail to connect unless Ollama is running locally, which wastes CPU on the client machine.
2. **Accidentally running models locally:** If the app attempts to execute a local fallback or download weights onto the MacBook, it will cause high memory pressure and battery drain.
3. **Hard-coding developer hostnames:** If names like `BigMac`, `westcat`, or port `11435` are hard-coded in UI instructions as defaults rather than examples, it will confuse generic users.
4. **Insecure cleartext network exposure:** If users expose their remote Ollama server publicly on the internet on `11434` without a secure tunnel, their raw text feeds will be sent unencrypted. SSH tunnels or Tailscale must be explicitly recommended.

## 7. Recommended Next Implementation Packet

After the human review of this baseline assessment, the recommended next task is to create the **Ollama Provider Integration & UI Settings Packet**. 
This packet will define:
- Extending `AppSettings` to persist `ollamaBaseURL`, `ollamaModelName`, `ollamaAPIKey`, and `useOllamaForSmartTranscription`.
- Adding an `OllamaTranscriptionService` implementation conforming to a new `SmartTranscriptionProvider` protocol.
- Adding a settings section in `QuickSettingsView` with "Test Connection" and "Test Inference" diagnostics.
- Documenting the SSH tunnel pattern directly in the Settings UI help tip.
