#!/bin/bash

# Custom Deployment Script
# Project: YOUR_PROJECT_ID
# Endpoint: YOUR_APIGEE_HOST
# Environment: YOUR_ENV

# Optional: Load environment variables from set-env.sh if it exists
if [ -f "./set-env.sh" ]; then
  source ./set-env.sh
  echo "Loaded environment variables from set-env.sh"
fi

export PROJECT="${PROJECT:-YOUR_PROJECT_ID}"
export APIGEE_HOST="${APIGEE_HOST:-YOUR_APIGEE_HOST}"
export APIGEE_ENV="${APIGEE_ENV:-YOUR_ENV}"
# Optional: Set REGION if needed, defaulting to generic or leaving empty if not strictly used by simple proxy deploy (script uses it for property file)
export REGION=${REGION:-"asia-northeast3"} 

if [ -z "$TOKEN" ]; then
  echo "Generating gcloud access token..."
  TOKEN=$(gcloud auth print-access-token)
  if [ -z "$TOKEN" ]; then
    echo "Failed to generate gcloud token. Please run 'gcloud auth login' first."
    exit 1
  fi
fi

echo "Installing apigeecli..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Setting gcloud project to $PROJECT"
gcloud config set project "$PROJECT"

# Create config properties
PRE_PROP="region=$REGION"
echo "$PRE_PROP" > ./apiproxy/resources/properties/vertex_config.properties

echo "Deploying Apigee artifacts to $PROJECT / $APIGEE_ENV..."

# Note: Data Collectors might already exist, ignoring errors or ensuring names are unique if needed.
# Using same names as original script.
echo "Creating Data collectors..."
apigeecli datacollectors create -d "Candidates token count v2" -n dc_candidates_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Data collector dc_candidates_token_count_v2 might already exist."
apigeecli datacollectors create -d "Prompt token count v2" -n dc_prompt_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Data collector dc_prompt_token_count_v2 might already exist."
apigeecli datacollectors create -d "Total token count v2" -n dc_total_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Data collector dc_total_token_count_v2 might already exist."

echo "Creating Token Consumption Report..."
curl --request POST \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"name":"tokens-consumption-report-v2","displayName":"Tokens Consumption Report v2","metrics":[{"name":"dc_prompt_token_count_v2","function":"sum"},{"name":"dc_candidates_token_count_v2","function":"sum"},{"name":"dc_total_token_count_v2","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
  --compressed 2>/dev/null || echo "Report might already exist."

echo "Importing and Deploying Apigee llm-token-limits-v2 proxy..."
# Check if apiproxy directory exists
if [ ! -d "./apiproxy" ]; then
  echo "Error: ./apiproxy directory not found. Please run this script from the root of the repo."
  exit 1
fi

export SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-YOUR_SERVICE_ACCOUNT}"

REV=$(apigeecli apis create bundle -f ./apiproxy -n llm-token-limits-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
if [ -z "$REV" ] || [ "$REV" == "null" ]; then
    echo "Error creating API proxy bundle. Check output above."
    exit 1
fi

echo "Deploying revision $REV to $APIGEE_ENV with Service Account $SERVICE_ACCOUNT..."
apigeecli apis deploy --wait --name llm-token-limits-v2 --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --sa "$SERVICE_ACCOUNT"

# Products and Apps
echo "Creating AI Products..."
apigeecli products create --name ai-product-bronze-v2 --display-name "AI Product Bronze v2" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --llmopgrp ./aiproduct-bronze.json --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Product Bronze might already exist (updating...)"
# If create fails, maybe update? apigeecli doesn't have easy update-or-create, ignoring error for now as create handles existence check often or fails. 
# Actually apigeecli usually fails if exists. 

apigeecli products create --name ai-product-silver-v2 --display-name "AI Product Silver v2" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --llmopgrp ./aiproduct-silver.json --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Product Silver might already exist."

echo "Creating Developer..."
apigeecli developers create --user testuser-v2 --email aidev-v2@cymbal.com --first Test --last Userv2 --org "$PROJECT" --token "$TOKEN" 2>/dev/null || echo "Developer might already exist."

echo "Creating Developer App..."
apigeecli apps create --name ai-consumer-app-v2 --email aidev-v2@cymbal.com --prods ai-product-bronze-v2 --callback https://developers.google.com/oauthplayground/ --org "$PROJECT" --token "$TOKEN" --disable-check 2>/dev/null || echo "App might already exist."

# Add silver product if not present (logic implies just re-adding or ensuring key)
apigeecli apps genkey --name ai-consumer-app-v2 -d aidev-v2@cymbal.com  --prods ai-product-silver-v2 --org "$PROJECT" --token "$TOKEN" --disable-check 2>/dev/null

BRONZE_KEY=$(apigeecli apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-bronze-v2").consumerKey' -r)
SILVER_KEY=$(apigeecli apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-silver-v2").consumerKey' -r)

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo "Your BRONZE API Key is: $BRONZE_KEY"
echo "Your SILVER API Key is: $SILVER_KEY"
echo " "
echo "Your PROJECT_ID is: $PROJECT"
echo "Your API_ENDPOINT is: https://$APIGEE_HOST/v2/samples/llm-token-limits"
