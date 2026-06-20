// Initialize variables to safe defaults
context.setVariable("is_final_usage_event", false);

var dataStr = context.getVariable("response.event.current.data");
if (dataStr) {
    try {
        var dataObj = JSON.parse(dataStr);
        if (dataObj && dataObj.type === "message_delta" && dataObj.usage) {
            var promptTokens = dataObj.usage.input_tokens || 0;
            var outputTokens = dataObj.usage.output_tokens || 0;
            var totalTokens = promptTokens + outputTokens;
            
            context.setVariable("prompt_token_count", java.lang.Integer.valueOf(promptTokens));
            context.setVariable("candidates_token_count", java.lang.Integer.valueOf(outputTokens));
            context.setVariable("total_token_count", java.lang.Integer.valueOf(totalTokens));
            context.setVariable("is_final_usage_event", true);
        }
    } catch (e) {
        // Ignore json parse error of individual event chunks if any
    }
}
