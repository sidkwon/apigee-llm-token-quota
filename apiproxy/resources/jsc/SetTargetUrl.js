// Split path segments to locate the location value
var path = context.getVariable("request.path");
var segments = path.split("/");
var locationsIndex = -1;

for (var i = 0; i < segments.length; i++) {
  if (segments[i] === "locations") {
    locationsIndex = i;
    break;
  }
}

if (locationsIndex !== -1 && locationsIndex + 1 < segments.length) {
  var location = segments[locationsIndex + 1];
  var targetHost = "";
  
  // Validate location to prevent path manipulation or query injection
  var locationRegex = /^[a-z0-9-]+$/i;
  if (!location || !locationRegex.test(location) || location === "global") {
    targetHost = "https://aiplatform.googleapis.com";
  } else {
    targetHost = "https://" + location + "-aiplatform.googleapis.com";
  }
  
  // Extract path suffix starting from /v1 (e.g. /v1/projects/...)
  var pathSuffix = "";
  var v1Index = path.indexOf("/v1/");
  if (v1Index !== -1) {
    pathSuffix = path.substring(v1Index);
  }
  
  var finalTargetUrl = targetHost + pathSuffix;
  context.setVariable("target.url", finalTargetUrl);
  
  // Prevent Apigee from appending the path suffix automatically
  context.setVariable("target.copy.pathsuffix", false);
  
  // Strip Accept-Encoding header from the request to backend to prevent ZlibError in clients
  context.removeVariable("request.header.accept-encoding");
}
