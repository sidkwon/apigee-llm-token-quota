// 1. 초기화: 변수가 null이 되어 XML의 default="0"이 실행되는 것을 원천 차단합니다.
// 반드시 java.lang.Integer를 사용하여 '진짜 숫자'를 미리 박아넣습니다.
context.setVariable("prompt_token_count", java.lang.Integer.valueOf(0));
context.setVariable("candidates_token_count", java.lang.Integer.valueOf(0));
context.setVariable("total_token_count", java.lang.Integer.valueOf(0));

// 디버깅용 변수 초기화
context.setVariable("debug.js.rawContentLength", 0);
context.setVariable("debug.js.lineCount", 0);
context.setVariable("debug.js.eventBlockCount", 0);
context.setVariable("debug.js.promptTokenFound", false);
context.setVariable("debug.js.candidatesTokenFound", false);
context.setVariable("debug.js.jsonParseErrors", "");
context.setVariable("debug.js.topLevelError", "");
context.setVariable("debug.js.rawContentInvalid", false);
context.setVariable("debug.js.targetVariable", "calloutResponse.content"); // 어떤 변수를 읽는지 명시

// SServiceCallout에서 지정한 'calloutResponse' 변수에서 content를 읽어옵니다.
var rawContent = context.getVariable("calloutResponse.content");
var promptCount = 0;
var candidatesCount = 0;

if (rawContent && typeof rawContent === 'string') {
    context.setVariable("debug.js.rawContentLength", rawContent.length);
    try {
        // 줄 단위로 분리 (CRLF 및 LF 지원)
        var lines = rawContent.split(/\r?\n/);
        context.setVariable("debug.js.lineCount", lines.length);
        var dataBuffer = "";
        var eventType = null;
        var blockIndex = 0;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            if (line.startsWith("event:")) {
                eventType = line.substring(6).trim();
            } else if (line.startsWith("data:")) {
                dataBuffer += line.substring(5).trim();
            } else if (line.trim() === "") {
                // 빈 줄은 이벤트 블록의 끝을 의미
                blockIndex++;
                if (dataBuffer && eventType) {
                    try {
                        var dataObj = JSON.parse(dataBuffer);

                        if (eventType === "message_start" && dataObj.type === "message_start") {
                            if (dataObj.message && dataObj.message.usage && typeof dataObj.message.usage.input_tokens === 'number') {
                                promptCount = dataObj.message.usage.input_tokens;
                                context.setVariable("debug.js.promptTokenFound", true);
                            }
                        } else if (eventType === "message_delta" && dataObj.type === "message_delta") {
                            if (dataObj.usage && typeof dataObj.usage.output_tokens === 'number') {
                                candidatesCount = dataObj.usage.output_tokens; // 항상 마지막 값으로 업데이트
                                context.setVariable("debug.js.candidatesTokenFound", true);
                            }
                        }
                    } catch (e) {
                        var errors = context.getVariable("debug.js.jsonParseErrors");
                        context.setVariable("debug.js.jsonParseErrors", errors + "Block " + blockIndex + ": " + e.message + " | ");
                    }
                }
                // 다음 이벤트를 위해 초기화
                dataBuffer = "";
                eventType = null;
            }
        }
        context.setVariable("debug.js.eventBlockCount", blockIndex);

        var totalCount = promptCount + candidatesCount;
        context.setVariable("prompt_token_count", java.lang.Integer.valueOf(promptCount));
        context.setVariable("candidates_token_count", java.lang.Integer.valueOf(candidatesCount));
        context.setVariable("total_token_count", java.lang.Integer.valueOf(totalCount));

    } catch (e) {
        context.setVariable("debug.js.topLevelError", e.message);
    }
} else {
    context.setVariable("debug.js.rawContentInvalid", true);
}
