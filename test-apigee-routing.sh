#!/bin/bash

# Test Script for Apigee PSC Routing & Load Balancer
# Usage: ./test-apigee-routing.sh

# Load environment configuration if available
if [ -f "./set-env.sh" ]; then
  source ./set-env.sh
fi

PROJECT=${PROJECT:-"YOUR_PROJECT_ID"}
APIGEE_HOST=${APIGEE_HOST:-"YOUR_APIGEE_HOST"}

# Path to apigeecli
export PATH=$PATH:$HOME/.apigeecli/bin

# Fetch the Load Balancer IP address from Terraform output
echo "Fetching Load Balancer IP from Terraform..."
LOAD_BALANCER_IP=$(cd terraform && terraform output -raw load_balancer_ip 2>/dev/null)

if [ -z "$LOAD_BALANCER_IP" ] || [[ "$LOAD_BALANCER_IP" == *"Error"* ]]; then
  echo "❌ Error: Could not retrieve load_balancer_ip from Terraform outputs. Please make sure terraform apply completed successfully."
  exit 1
fi

echo "Found Load Balancer IP: $LOAD_BALANCER_IP"
echo "Target Hostname: $APIGEE_HOST"
echo "Target Project: $PROJECT"
echo ""

# 1. Test basic TCP connectivity
echo "Step 1: Testing TCP connection to Load Balancer IP on port 443..."
if command -v nc &> /dev/null; then
  nc -zv -w 5 "$LOAD_BALANCER_IP" 443 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ Error: Failed TCP connection to $LOAD_BALANCER_IP:443."
    exit 1
  fi
  echo "✅ TCP Connection Successful."
else
  echo "⚠️ nc command not found, skipping TCP check."
fi
echo ""

# 2. Try fetching the API key for llm-token-limits-v2 proxy if deployed
echo "Step 2: Checking if API keys are available in $PROJECT..."
TOKEN=$(gcloud auth print-access-token 2>/dev/null)
API_KEY=""

if [ -n "$TOKEN" ]; then
  API_KEY=$("$HOME/.apigeecli/bin/apigeecli" apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); apps = data if isinstance(data, list) else [data]; print(next((c.get('consumerKey') for app in apps for c in app.get('credentials', []) if any(p.get('apiproduct', '') == 'ai-product-bronze-v2' for p in c.get('apiProducts', []))), ''))" 2>/dev/null)
fi

URL="https://$APIGEE_HOST/v2/samples/llm-token-limits/v1/projects/$PROJECT/locations/global/publishers/anthropic/models/claude-sonnet-4-6:streamRawPredict"

echo "Step 3: Sending HTTPS test request to Apigee..."
if [ -n "$API_KEY" ] && [ "$API_KEY" != "null" ]; then
  echo "✅ Found API Key: $API_KEY"
  echo "Sending predict request with API Key..."
  
  curl -i -X POST "$URL" \
    --resolve "$APIGEE_HOST:443:$LOAD_BALANCER_IP" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-apikey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "anthropic_version": "vertex-2023-10-16",
      "messages": [
        {"role": "user", "content": [{"type": "text", "text": "Hello"}]}
      ],
      "max_tokens": 10
    }'
else
  echo "⚠️ API Key not found (llm-token-limits-v2 proxy might not be deployed yet)."
  echo "Sending request without API Key to verify routing..."
  
  curl -i -k --resolve "$APIGEE_HOST:443:$LOAD_BALANCER_IP" "$URL"
fi

echo ""
echo "Verification complete!"
