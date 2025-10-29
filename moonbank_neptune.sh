#!/bin/bash

PROJECT_ID="moonbank-neptune"
REGION="us-central1"
DATASET_NAME="neptune_data"
FUNCTION_NAME="neptune-processor"
TOPIC_NAME="activities"

echo "========================================="
echo "NEPTUNE Deployment Script"
echo "========================================="

echo "Setting project..."
gcloud config set project $PROJECT_ID

# Create BigQuery dataset
echo ""
echo "Creating BigQuery dataset..."
bq mk --dataset --location=US $PROJECT_ID:$DATASET_NAME || echo "Dataset may already exist"

# Create table schema
echo ""
echo "Creating BigQuery table..."
bq mk --table $PROJECT_ID:$DATASET_NAME.activities \
  timestamp:TIMESTAMP,event_type:STRING,user_id:STRING,details:JSON || echo "Table may already exist"

# Create Pub/Sub topic if it doesn't exist
echo ""
echo "Creating Pub/Sub topic..."
gcloud pubsub topics create $TOPIC_NAME --project=$PROJECT_ID || echo "Topic may already exist"

# Deploy Cloud Function
echo ""
echo "Deploying Cloud Function..."
gcloud functions deploy $FUNCTION_NAME \
  --runtime python311 \
  --trigger-topic $TOPIC_NAME \
  --entry-point process_message \
  --region $REGION \
  --set-env-vars PROJECT_ID=$PROJECT_ID,DATASET=$DATASET_NAME

# Validation Steps
echo ""
echo "========================================="
echo "VALIDATION CHECKS"
echo "========================================="

# Check BigQuery
echo ""
echo "✓ Checking BigQuery dataset and table..."
bq show $PROJECT_ID:$DATASET_NAME.activities
BQ_STATUS=$?

# Check Cloud Function
echo ""
echo "✓ Checking Cloud Function deployment..."
gcloud functions describe $FUNCTION_NAME --region=$REGION
FUNCTION_STATUS=$?

# Check Pub/Sub Topic
echo ""
echo "✓ Checking Pub/Sub topic..."
gcloud pubsub topics describe $TOPIC_NAME
TOPIC_STATUS=$?

# Send Test Message
echo ""
echo "========================================="
echo "SENDING TEST MESSAGE"
echo "========================================="
TEST_MESSAGE='{"event_type":"account_creation","user_id":"test_user_123","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
echo "Test message: $TEST_MESSAGE"

gcloud pubsub topics publish $TOPIC_NAME \
  --message="$TEST_MESSAGE" \
  --project=$PROJECT_ID

echo ""
echo "Waiting 10 seconds for function to process..."
sleep 10

# Check function logs
echo ""
echo "✓ Checking function logs..."
gcloud functions logs read $FUNCTION_NAME \
  --region=$REGION \
  --limit=10

# Query BigQuery for test data
echo ""
echo "✓ Querying BigQuery for test message..."
bq query --use_legacy_sql=false \
"SELECT 
  timestamp,
  event_type,
  user_id,
  JSON_EXTRACT_SCALAR(details, '$.event_type') as detail_event
FROM \`$PROJECT_ID.$DATASET_NAME.activities\`
ORDER BY timestamp DESC
LIMIT 5"

# Summary
echo ""
echo "========================================="
echo "DEPLOYMENT SUMMARY"
echo "========================================="

if [ $BQ_STATUS -eq 0 ]; then
  echo "✅ BigQuery: SUCCESS"
else
  echo "❌ BigQuery: FAILED"
fi

if [ $FUNCTION_STATUS -eq 0 ]; then
  echo "✅ Cloud Function: SUCCESS"
else
  echo "❌ Cloud Function: FAILED"
fi

if [ $TOPIC_STATUS -eq 0 ]; then
  echo "✅ Pub/Sub Topic: SUCCESS"
else
  echo "❌ Pub/Sub Topic: FAILED"
fi

echo ""
echo "========================================="
echo "USEFUL LINKS"
echo "========================================="
echo ""
echo "📊 BigQuery Console:"
echo "https://console.cloud.google.com/bigquery?project=$PROJECT_ID&ws=!1m5!1m4!4m3!1s${PROJECT_ID}!2s${DATASET_NAME}!3sactivities"
echo ""
echo "⚡ Cloud Functions Console:"
echo "https://console.cloud.google.com/functions/details/$REGION/$FUNCTION_NAME?project=$PROJECT_ID"
echo ""
echo "📨 Pub/Sub Topics Console:"
echo "https://console.cloud.google.com/cloudpubsub/topic/list?project=$PROJECT_ID"
echo ""
echo "📈 Cloud Functions Logs:"
echo "https://console.cloud.google.com/logs/query?project=$PROJECT_ID&query=resource.type%3D%22cloud_function%22%0Aresource.labels.function_name%3D%22$FUNCTION_NAME%22"
echo ""
echo "🔍 Looker Studio (create new report):"
echo "https://lookerstudio.google.com/navigation/reporting"
echo ""
echo "========================================="
echo "NEXT STEPS"
echo "========================================="
echo "1. Review the validation checks above"
echo "2. Check the Cloud Functions logs for any errors"
echo "3. Verify test data appears in BigQuery"
echo "4. Connect Looker Studio to BigQuery dataset"
echo "5. Create dashboard with event_type counts"
echo ""
echo "Deployment complete!"