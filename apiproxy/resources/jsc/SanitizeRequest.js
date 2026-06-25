var reqContent = context.getVariable("request.content");

if (reqContent) {
    var payload;
    try {
        payload = JSON.parse(reqContent);
    } catch (e) {
        print("SanitizeRequest: Failed to parse JSON content: " + e);
        payload = null;
    }

    if (payload && payload.messages &&
        (Object.prototype.toString.call(payload.messages) === '[object Array]')) {

        var originalLength = payload.messages.length;
        payload.messages = payload.messages.filter(function (msg) {
            // Keep if role is NOT assistant OR content is NOT empty
            if (msg.role === "assistant") {
                // Check for empty array content
                if (Object.prototype.toString.call(msg.content) === '[object Array]' && msg.content.length === 0) {
                    return false;
                }
                // Check for empty string content
                if (typeof msg.content === "string" && msg.content.trim() === "") {
                    return false;
                }
                // Check for null/undefined content
                if (msg.content === null || msg.content === undefined) {
                    return false;
                }
            }
            return true;
        });

        if (payload.messages.length < originalLength) {
            print("Sanitized messages: Removed " + (originalLength - payload.messages.length) + " empty assistant messages.");
            context.setVariable("request.content", JSON.stringify(payload));
        }
    }
}

// Normalize model variable to clean categories (sonnet, haiku, opus) for API Product matching
var rawModel = context.getVariable("model");
if (!rawModel || rawModel.indexOf("count-token") !== -1) {
    if (typeof payload !== "undefined" && payload && payload.model) {
        rawModel = payload.model;
    }
}

var normalizedModel = "sonnet"; // default fallback
if (rawModel) {
    var lowerModel = rawModel.toLowerCase();
    if (lowerModel.indexOf("haiku") !== -1) {
        normalizedModel = "haiku";
    } else if (lowerModel.indexOf("opus") !== -1) {
        normalizedModel = "opus";
    } else if (lowerModel.indexOf("sonnet") !== -1) {
        normalizedModel = "sonnet";
    }
}
context.setVariable("model", normalizedModel);

