# 🔍 Apigee LLM Token Quota Troubleshooting History

This document lists the history of issues identified, analyzed, and fixed during this development session.

---

## 1. Claude Code CLI "API error · Retrying" Loop
*   **Symptom**:
    Claude Code CLI hit a continuous retrying loop with `API error` when trying to run prompts.
*   **Root Cause**:
    Claude Code defaults to calling Vertex AI under regional locations (like `locations/us-central1`). Our Apigee proxy target URL was hardcoded to `https://aiplatform.googleapis.com` (which only works for global/default location requests). Sending regional path segments (e.g. `locations/us-central1`) to the global host returns a `500 Internal Server Error` from Vertex AI.
*   **Fix**:
    Implemented dynamic regional routing in Apigee via a JavaScript policy (`JS-SetTargetUrl`). It parses the region parameter (e.g. `us-central1`, `us-east5`) from the incoming request path suffix and rewrites the target host dynamically to `https://[REGION]-aiplatform.googleapis.com`.

---

## 2. Apigee Target Routing "Request path cannot be empty" (EmptyPath) Error
*   **Symptom**:
    After implementing regional routing, requests failed with HTTP 500:
    ```json
    {"fault":{"faultstring":"Request path cannot be empty","detail":{"errorcode":"protocol.http.EmptyPath"}}}
    ```
*   **Root Cause**:
    In Apigee, if you programmatically override `target.url` to a hostname without a trailing slash (e.g., `https://us-central1-aiplatform.googleapis.com`), the router considers the URL path component empty and throws a `protocol.http.EmptyPath` error.
*   **Fix**:
    Appended a trailing slash (`/`) to the dynamically computed host names (e.g., `https://[REGION]-aiplatform.googleapis.com/`).

---

## 3. Google API "404 Not Found" (Double Slash) Error
*   **Symptom**:
    After adding the trailing slash, requests failed with a Google 404 HTML page: `"The requested URL / was not found on this server."`
*   **Root Cause**:
    Because `target.url` had a trailing slash (e.g., `...com/`) and Apigee automatically appended the request path suffix starting with a slash (e.g., `/v1/projects/...`), the final generated backend target URL contained a double slash: `https://us-central1-aiplatform.googleapis.com//v1/projects/...`. The Google Front End (GFE) rejected this malformed URL.
*   **Fix**:
    Updated `SetTargetUrl.js` to construct the entire target URL dynamically (joining the host and the `/v1/...` path suffix) and set `target.copy.pathsuffix = false` in the JavaScript context to disable Apigee's automatic path suffix appending.

---

## 4. Unsupported Models / Product Operations
*   **Symptom**:
    Changing `"ANTHROPIC_MODEL"` to `"claude-opus-4-8"` in settings resulted in unauthorized access errors from Apigee.
*   **Root Cause**:
    The allowed Operations inside the API Products (`aiproduct-bronze.json` and `aiproduct-silver.json`) were restricted to `claude-sonnet-4-6` and `claude-haiku-4-5`.
*   **Fix**:
    *   Added the `claude-opus-4-8` configuration block to both `aiproduct-bronze.json` and `aiproduct-silver.json`.
    *   Updated the `deploy-llm-token-limits-v2.sh` script to run `apigeecli products update` if the product creation fails (since products already exist), ensuring updates are successfully pushed to Apigee.

---

## 5. Double Quota Consumption and Analytics Log
*   **Symptom**:
    Users were charged double the tokens they actually consumed, and token consumption reports showed duplicate entries for every single request.
*   **Root Cause**:
    The PostFlow Response flow in both Proxy Endpoint (`apiproxy/proxies/default.xml`) and Target Endpoint (`apiproxy/targets/default.xml`) contained the exact same steps (`JS-ExtractClaudeTokens`, `LTQ-TokenCount`, and `DC-CollectTokenCounts`). Both flows executed sequentially in Apigee's response lifecycle, running all three policies twice per API call.
*   **Fix**:
    Removed the duplicate steps from the Proxy Endpoint PostFlow Response, keeping them only in the Target Endpoint PostFlow Response.

---

## 6. Broken Test Script JSON Parser
*   **Symptom**:
    Test scripts (`test-apigee-routing.sh` and `test-quota.sh`) printed `⚠️ API Key not found`, failing to fetch API keys dynamically.
*   **Root Cause**:
    The inline python scripts in bash assumed `apigeecli apps get` returned a single JSON object. However, `apigeecli` returns a JSON array wrapping the app dictionary (e.g. `[{...}]`), which caused an `AttributeError` in python, resolving to an empty string.
*   **Fix**:
    *   Updated the python parser to handle both array and object formats robustly.
    *   Used the absolute path `$HOME/.apigeecli/bin/apigeecli` in scripts to prevent failures due to missing path configurations.

---

## 7. Dynamic Model Extraction Failed on rawPredict Requests
*   **Symptom**:
    Requests to `rawPredict` endpoints failed with HTTP 500 error:
    `{"fault":{"faultstring":"Unresolved variable : model","detail":{"errorcode":"entities.UnresolvedVariable"}}}`
*   **Root Cause**:
    The request path suffix extraction pattern in `EV-ExtractRequest.xml` was hardcoded to match `:streamRawPredict`. When Claude Code called the non-streaming `:rawPredict` endpoint, the pattern failed to match. As a result, the `{model}` variable remained unresolved, causing the `LTQ-TokenEnforce` policy to fail when referencing the model.
*   **Fix**:
    Updated the extraction pattern in `EV-ExtractRequest.xml` to `/v1/projects/{extracted_project}/locations/{extracted_location}/publishers/anthropic/models/{model}:{prediction_type}`. This extracts both the model and the prediction type dynamically, supporting both `streamRawPredict` and `rawPredict` requests.

---

## 8. com.apigee.errors.http.server.GatewayTimeout (504) Error
*   **Symptom**:
    Long-running or streaming LLM requests failed with HTTP 504 Gateway Timeout error.
*   **Root Cause**:
    *   **GCLB Backend Service**: The default timeout for Google Cloud Load Balancer (GCLB) Backend Service is 30 seconds.
    *   **Apigee Target Connection**: The default connection and I/O timeout for Apigee Target Connection is 55 seconds.
    LLM prompt generation or streaming output regularly exceeds these short limits, causing either GCLB or Apigee to prematurely terminate the connection.
*   **Fix**:
    *   Increased GCLB Backend Service timeout to 300 seconds (5 minutes) by adding `timeout_sec = 300` to the `google_compute_backend_service` resource in [`terraform/routing.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/routing.tf).
    *   Increased Apigee Target Connection timeouts to 60 seconds connection / 300 seconds IO by adding a `<Properties>` block in [`apiproxy/targets/default.xml`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/apiproxy/targets/default.xml).

