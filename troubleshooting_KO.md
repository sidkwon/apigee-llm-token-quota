# 🔍 Apigee LLM 토큰 쿼타 트러블슈팅 이력

이 문서는 본 개발 세션 동안 발견, 분석 및 해결된 문제들의 트러블슈팅 내역을 정리한 파일입니다.

---

## 1. Claude Code CLI "API error · Retrying" 루프 현상
*   **증상**:
    Claude Code CLI에서 프롬프트를 전송하려고 할 때 `API error` 발생과 함께 계속해서 재시도 루프가 반복됨.
*   **원인**:
    Claude Code 클라이언트는 설정을 변경하지 않을 경우 기본값으로 리전별 위치(예: `locations/us-central1`)를 대상으로 Vertex AI를 호출합니다. 기존 Apigee 타겟 URL은 `https://aiplatform.googleapis.com` (글로벌 호스트)으로 고정되어 있어서, 리전 정보를 포함한 경로(`locations/us-central1`)를 해당 호스트로 호출하면 Vertex AI Gateway에서 `500 Internal Server Error`를 반환하게 됩니다.
*   **해결책**:
    Apigee에서 동적 리전 라우팅이 처리될 수 있도록 JavaScript 정책(`JS-SetTargetUrl`)을 추가했습니다. 요청 경로 내 리전 인자(예: `us-central1`, `us-east5`)를 파싱하여 백엔드 호스트를 `https://[REGION]-aiplatform.googleapis.com` 형식으로 실시간 재작성합니다.

---

## 2. Apigee 타겟 라우팅 "Request path cannot be empty" (EmptyPath) 에러
*   **증상**:
    리전별 동적 라우팅 적용 후, 호출 시 HTTP 500 에러와 함께 다음 메시지가 반환됨:
    ```json
    {"fault":{"faultstring":"Request path cannot be empty","detail":{"errorcode":"protocol.http.EmptyPath"}}}
    ```
*   **원인**:
    Apigee 정책 내에서 `target.url` 값을 슬래시가 없는 호스트명(예: `https://us-central1-aiplatform.googleapis.com`)으로 재설정하면, 경로(path) 구성 요소가 비어 있는 것으로 인식되어 `protocol.http.EmptyPath` 오류가 발생합니다.
*   **해결책**:
    동적으로 연산된 호스트명 주소 끝에 항상 트레일링 슬래시(`/`)를 붙이도록 수정했습니다. (예: `https://[REGION]-aiplatform.googleapis.com/`)

---

## 3. Google API "404 Not Found" (이중 슬래시) 에러
*   **증상**:
    트레일링 슬래시 적용 후 호출 시, Google의 GFE HTML 404 에러 페이지가 리턴됨: `"The requested URL / was not found on this server."`
*   **원인**:
    `target.url` 끝에 슬래시가 붙어 있는 상태(`...com/`)에서 Apigee가 원래 요청의 나머지 경로인 `/v1/projects/...`를 자동으로 덧붙이면서 백엔드 대상 주소에 이중 슬래시(`https://us-central1-aiplatform.googleapis.com//v1/projects/...`)가 발생하였고, 이를 Google API Gateway 측에서 인식하지 못해 404가 발생했습니다.
*   **해결책**:
    JavaScript 코드(`SetTargetUrl.js`) 내에서 호스트명과 추출된 `/v1` 이하 경로를 직접 조합하여 완전한 URL을 완성한 후, Apigee가 경로를 자동으로 덧붙이지 않도록 `target.copy.pathsuffix = false` 설정을 추가했습니다.

---

## 4. 지원하지 않는 모델 호출 차단 문제 (API Product)
*   **증상**:
    `settings.json`에서 `"ANTHROPIC_MODEL"`을 `"claude-opus-4-8"`로 변경 시 권한 없음(unauthorized) 에러가 발생함.
*   **원인**:
    기존 API Product 제품 정책(`aiproduct-bronze.json`, `aiproduct-silver.json`)에 허용된 모델이 `claude-sonnet-4-6` 및 `claude-haiku-4-5`로만 제한되어 있었습니다.
*   **해결책**:
    *   두 API 제품 설정 파일에 `claude-opus-4-8` 모델을 허용하도록 Operation 구성을 추가했습니다.
    *   `deploy-llm-token-limits-v2.sh` 배포 스크립트가 이미 제품이 존재할 경우 업데이트를 수행하지 못하던 점을 수정하여 `apigeecli products update` 명령이 정상적으로 호출되도록 수정했습니다.

---

## 5. 이중 쿼타 차감 및 분석 중복 로깅
*   **증상**:
    실제 사용한 토큰의 2배에 달하는 양이 쿼타에서 차감되고 분석 대시보드 리포트에도 중복으로 카운팅되어 기록됨.
*   **원인**:
    `JS-ExtractClaudeTokens`(응답 파싱), `LTQ-TokenCount`(토큰 차감), `DC-CollectTokenCounts`(통계 수집) 정책이 Proxy Endpoint의 PostFlow Response와 Target Endpoint의 PostFlow Response 모두에 동일하게 등록되어 있었습니다. 이로 인해 응답 라이프사이클을 돌며 세 정책이 매 요청마다 두 번씩 실행되었습니다.
*   **해결책**:
    프록시 레이어([`apiproxy/proxies/default.xml`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/apiproxy/proxies/default.xml))의 중복 수집 단계를 제거하고, 타겟 레이어([`apiproxy/targets/default.xml`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/apiproxy/targets/default.xml))에서만 수집이 일어날 수 있도록 리팩토링했습니다.

---

## 6. 테스트 스크립트의 API Key 파싱 에러
*   **증상**:
    `test-apigee-routing.sh` 및 `test-quota.sh`에서 API 키를 파싱하지 못하고 `⚠️ API Key not found` 경고를 출력함.
*   **원인**:
    `apigeecli apps get` 호출 시 JSON 배열 형태로 정보가 반환되지만, inline 파이썬 스크립트가 단일 객체 데이터로 오인하고 파싱을 진행하여 `AttributeError`가 발생해 키 값이 빈 문자열로 수렴했습니다.
*   **해결책**:
    *   반환된 데이터가 객체인지 배열인지와 무관하게 안전하게 `credentials` 구조에 접근하여 키를 꺼내오도록 파이썬 구문을 정교화했습니다.
    *   환경별 `apigeecli` 경로 문제를 차단하기 위해 스크립트 내에서 `$HOME/.apigeecli/bin/apigeecli` 절대 경로를 사용하도록 고정했습니다.

---

## 7. rawPredict 요청 시 동적 모델명 추출 실패 문제
*   **증상**:
    `rawPredict` 엔드포인트 호출 시 HTTP 500 에러와 함께 다음 메시지가 반환됨:
    `{"fault":{"faultstring":"Unresolved variable : model","detail":{"errorcode":"entities.UnresolvedVariable"}}}`
*   **원인**:
    `EV-ExtractRequest.xml` 파일에 등록된 요청 경로 추출 패턴이 `:streamRawPredict` 메서드로 고정되어 있어서, Claude Code가 스트리밍을 사용하지 않는 `:rawPredict` 메서드로 예측을 호출할 때 패턴이 매치되지 않았습니다. 결과적으로 `{model}` 변수가 정의되지 않은 채로 `LTQ-TokenEnforce` 정책이 실행되어 오류가 발생했습니다.
*   **해결책**:
    `EV-ExtractRequest.xml`의 추출 패턴을 `/v1/projects/{extracted_project}/locations/{extracted_location}/publishers/anthropic/models/{model}:{prediction_type}`으로 업데이트했습니다. 이를 통해 모델명과 예측 타입(`streamRawPredict` / `rawPredict`)을 동적으로 추출하여 두 가지 엔드포인트 방식을 모두 정상 지원하게 되었습니다.

---

## 8. com.apigee.errors.http.server.GatewayTimeout (504) 에러 발생
*   **증상**:
    오래 걸리는 LLM 프롬프트 생성 또는 스트리밍 요청 시 HTTP 504 Gateway Timeout 에러가 발생함.
*   **원인**:
    *   **GCLB Backend Service**: Google Cloud 부하 분산기(GCLB) 백엔드 서비스의 기본 타임아웃은 30초로 설정되어 있습니다.
    *   **Apigee Target Connection**: Apigee의 타겟 백엔드 연결 및 IO 타임아웃 기본값은 55초로 설정되어 있습니다.
    LLM의 생성이나 스트리밍 답변 시간이 해당 임계치를 초과하면서 커넥션이 조기에 강제 종료되었습니다.
*   **해결책**:
    *   GCLB 백엔드 서비스의 타임아웃을 300초(5분)로 연장하기 위해 [`terraform/routing.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/routing.tf) 파일 내 `google_compute_backend_service` 리소스에 `timeout_sec = 300` 옵션을 추가했습니다.
    *   Apigee 타겟 연결 타임아웃을 연결 60초 / IO 300초(5분)로 연장하기 위해 [`apiproxy/targets/default.xml`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/apiproxy/targets/default.xml) 파일 내 `<HTTPTargetConnection>` 요소에 `<Properties>` 블록을 추가했습니다.

