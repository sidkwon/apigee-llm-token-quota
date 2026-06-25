// 1. Get requester email (prioritize google.email from Google OAuth token, then developer.email)
var email = context.getVariable("google.email");
if (!email) {
    email = context.getVariable("developer.email");
}
if (!email) {
    email = context.getVariable("verifyapikey.VA-VerifyAPIKey.developer.email");
}
if (!email) {
    email = "unknown_user";
}

// 2. Sanitize email value to comply with GCP label constraints
// Allowed: lowercase letters, numbers, underscores, and dashes
var sanitizedEmail = email.toLowerCase()
                          .replace(/[^a-z0-9_-]/g, "_");

// Truncate to max 63 characters
if (sanitizedEmail.length > 63) {
    sanitizedEmail = sanitizedEmail.substring(0, 63);
}

// 3. Create JSON payload for billing labels
var labelsJson = '{"claude_requester":"' + sanitizedEmail + '"}';

try {
    // 4. Base64 encode using Java Base64 class (Rhino/Nashorn engine runs on JVM)
    var base64Encoded = java.util.Base64.getEncoder().encodeToString(
        new java.lang.String(labelsJson).getBytes("UTF-8")
    );
    
    // 5. Inject as X-Vertex-AI-Labels HTTP Header
    context.setVariable("request.header.X-Vertex-AI-Labels", base64Encoded);
    
    // For debugging in Apigee Trace
    context.setVariable("debug.labels.raw", labelsJson);
    context.setVariable("debug.labels.encoded", base64Encoded);
} catch (e) {
    print("Error encoding billing labels: " + e.message);
}
