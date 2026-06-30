// Pure JS Base64 helper functions to avoid Rhino/Nashorn Java package resolution issues
function utf8ToBase64(str) {
    var utf8Str = unescape(encodeURIComponent(str));
    var charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var output = "";
    var i = 0;
    
    while (i < utf8Str.length) {
        var chr1 = utf8Str.charCodeAt(i++);
        var chr2 = i < utf8Str.length ? utf8Str.charCodeAt(i++) : NaN;
        var chr3 = i < utf8Str.length ? utf8Str.charCodeAt(i++) : NaN;
        
        var enc1 = chr1 >> 2;
        var enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        var enc3 = isNaN(chr2) ? 64 : ((chr2 & 15) << 2) | (chr3 >> 6);
        var enc4 = isNaN(chr3) ? 64 : chr3 & 63;
        
        output += charSet.charAt(enc1) +
                  charSet.charAt(enc2) +
                  charSet.charAt(enc3) +
                  charSet.charAt(enc4);
    }
    return output;
}

function base64ToUtf8(str) {
    var charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var output = "";
    var i = 0;
    
    str = str.replace(/[^A-Za-z0-9\+\/]/g, "");
    
    while (i < str.length) {
        var enc1 = charSet.indexOf(str.charAt(i++));
        var enc2 = charSet.indexOf(str.charAt(i++));
        var enc3 = i < str.length ? charSet.indexOf(str.charAt(i++)) : 64;
        var enc4 = i < str.length ? charSet.indexOf(str.charAt(i++)) : 64;
        
        var chr1 = (enc1 << 2) | (enc2 >> 4);
        var chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
        var chr3 = ((enc3 & 3) << 6) | enc4;
        
        output += String.fromCharCode(chr1);
        if (enc3 != 64) {
            output += String.fromCharCode(chr2);
        }
        if (enc4 != 64) {
            output += String.fromCharCode(chr3);
        }
    }
    
    try {
        return decodeURIComponent(escape(output));
    } catch (e) {
        return output;
    }
}

// 1. Requester 이메일 추출 (google.email 우선, 차선으로 developer.email)
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

// 2. 이메일 값 GCP 레이블 규격에 맞게 정제
var sanitizedEmail = email.toLowerCase()
                          .replace(/[^a-z0-9_-]/g, "_");

if (sanitizedEmail.length > 63) {
    sanitizedEmail = sanitizedEmail.substring(0, 63);
}

// 3. 기존 X-Vertex-AI-Labels 헤더가 존재하면 추출하여 파싱
var existingHeader = context.getVariable("request.header.X-Vertex-AI-Labels");
var labelsObj = {};

if (existingHeader) {
    try {
        var decodedStr = base64ToUtf8(existingHeader);
        labelsObj = JSON.parse(decodedStr);
    } catch (e) {
        print("Error decoding existing billing labels: " + e.message);
    }
}

// 4. 새로운 레이블 병합
labelsObj["claude_requester"] = sanitizedEmail;

// 5. JSON 직렬화 및 Base64 인코딩 진행
var labelsJson = JSON.stringify(labelsObj);

try {
    var base64Encoded = utf8ToBase64(labelsJson);
    
    // 6. X-Vertex-AI-Labels HTTP 헤더에 최종 반영
    context.setVariable("request.header.X-Vertex-AI-Labels", base64Encoded);
    
    // Apigee Trace 디버깅용 변수 설정
    context.setVariable("debug.labels.raw", labelsJson);
    context.setVariable("debug.labels.encoded", base64Encoded);
} catch (e) {
    print("Error encoding billing labels: " + e.message);
}
