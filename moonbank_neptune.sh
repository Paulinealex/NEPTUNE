#!/bin/bash

PROJECT_ID="moonbank-neptune"
REGION="us-central1"
DATASET_NAME="neptune_data"

echo "Setting project..."
gcloud config set project $PROJECT_ID

# Create BigQuery dataset
echo "Creating BigQuery dataset..."
bq mk --dataset --location=US $PROJECT_ID:$DATASET_NAME

# Create table schema
bq mk --table $PROJECT_ID:$DATASET_NAME.activities \
  timestamp:TIMESTAMP,event_type:STRING,user_id:STRING,details:JSON

# Deploy Cloud Function
echo "Deploying Cloud Function..."
gcloud functions deploy neptune-processor \
  --runtime python311 \
  --trigger-topic activities \
  --entry-point process_message \
  --region $REGION \
  --set-env-vars PROJECT_ID=$PROJECT_ID,DATASET=$DATASET_NAME

echo "Deployment complete!"