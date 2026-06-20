#!/bin/bash

# Test Script for Quota Enforcement
# Usage: ./test-quota.sh [NUM_REQUESTS]

COUNT=${1:-20} # Default 20 requests
echo "Running $COUNT requests with random complex prompts to test quota..."

# Ensure we have a token
if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

# Ensure apigeecli is in PATH
export PATH=$PATH:$HOME/.apigeecli/bin

# Load env
if [ -f "./set-env.sh" ]; then
  source ./set-env.sh
fi

PROJECT=${PROJECT:-"YOUR_PROJECT_ID"}
APIGEE_HOST=${APIGEE_HOST:-"YOUR_APIGEE_HOST"}
# Fetch Bronze Key dynamically if not set
if [ -z "$API_KEY" ]; then
  echo "Fetching Bronze API Key..."
  API_KEY=$("$HOME/.apigeecli/bin/apigeecli" apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); apps = data if isinstance(data, list) else [data]; print(next((c.get('consumerKey') for app in apps for c in app.get('credentials', []) if any(p.get('apiproduct', '') == 'ai-product-bronze-v2' for p in c.get('apiProducts', []))), ''))" 2>/dev/null)

fi

if [ -z "$API_KEY" ] || [ "$API_KEY" == "null" ]; then
    echo "❌ API Key is empty. Please ensure it is exported in your environment or 'apigeecli' can fetch it."
    exit 1
fi

echo "Using API Key: $API_KEY"

# URL="https://$APIGEE_HOST/v2/samples/llm-token-limits/v1/projects/$PROJECT/locations/global/publishers/anthropic/models/claude-sonnet-4-5@20250929:streamRawPredict"
URL="https://$APIGEE_HOST/v2/samples/llm-token-limits/v1/projects/$PROJECT/locations/global/publishers/anthropic/models/claude-sonnet-4-6:streamRawPredict"
# URL="https://$APIGEE_HOST/v2/samples/llm-token-limits/v1/projects/$PROJECT/locations/global/publishers/anthropic/models/claude-haiku-4-5:streamRawPredict"


# Define complex prompts
PROMPTS=(
  "Write a detailed history of the Roman Empire, focusing on the transition from Republic to Empire, including key figures like Julius Caesar and Augustus. Make it at least 500 words."
  "Explain the principles of Quantum Mechanics to a 5-year-old using analogies involving animals and playgrounds. Include Schrödinger's cat."
  "Generate a Python script that implements a full REST API using FastAPI, SQLAlchemy, and Pydantic, including user authentication and CRUD operations for a 'Books' resource."
  "Analyze the socio-economic impacts of the Industrial Revolution in 19th century Europe, contrasting the experiences of the working class with the aristocracy."
  "Write a Shakespearean sonnet about the frustrations of debugging code that works on my machine but fails in production."
  "Summarize the plot of the movie 'Inception' in reverse chronological order, explaining the dream layers in detail."
)

PROMPT_COUNT=${#PROMPTS[@]}

for i in $(seq 1 $COUNT); do
    # Pick random prompt
    RAND_INDEX=$((RANDOM % PROMPT_COUNT))
    SELECTED_PROMPT="${PROMPTS[$RAND_INDEX]}"
    
    echo -n "Request $i: Sending prompt [${SELECTED_PROMPT:0:30}...] "
    
    # Request with increased max_tokens to consume more quota
    RESPONSE=$(curl -s -i -X POST "$URL" \
      -H "Authorization: Bearer $TOKEN" \
      -H "x-apikey: $API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"anthropic_version\": \"vertex-2023-10-16\",
        \"messages\": [
          {\"role\": \"user\", \"content\": \"$SELECTED_PROMPT\"}
        ],
        \"max_tokens\": 1024,
        \"stream\": true
      }")
    
    # Extract Status Code
    STATUS=$(echo "$RESPONSE" | grep "HTTP/" | awk '{print $2}' | tail -1)
    
    # Extract Debug Headers if present
    QUOTA_USED=$(echo "$RESPONSE" | grep -i "x-debug-quota-used" | awk '{print $2}' | tr -d '\r')
    
    echo "-> Status: $STATUS | Quota Used: ${QUOTA_USED:-N/A}"
    
    if [ "$STATUS" == "429" ]; then
        echo -e "\n✅ Quota Exceeded! Test Successful (429 Received)."
        exit 0
    fi
    
    # Verify if we got a valid response or Auth error
    if [ "$STATUS" == "401" ]; then
         echo "❌ Auth Error (401). Check API Key or Token."
         exit 1
    fi
    
    sleep 0.5
done

echo "Finished $COUNT requests. If no 429, try increasing count or prompt length."

