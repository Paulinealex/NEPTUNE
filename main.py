import base64
import json
from google.cloud import bigquery
from datetime import datetime
import os

# Get environment variables set by deployment script
PROJECT_ID = os.environ.get('PROJECT_ID', 'moonbank-neptune')
DATASET = os.environ.get('DATASET', 'neptune_data')
table_id = f"{PROJECT_ID}.{DATASET}.activities"


def process_message(event, context):
    """Triggered by a message on a Cloud Pub/Sub topic.
    Args:
        event (dict): Event payload.
        context (google.cloud.functions.Context): Metadata for the event.
    """
    # Decode message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    print(f"Raw message received: {pubsub_message}")
    
    try:
        # Parse JSON message
        data = json.loads(pubsub_message)
        
        # Initialize BigQuery client
        client = bigquery.Client()
        
        # Prepare row with proper schema
        row = {
            "timestamp": data.get("timestamp") or datetime.utcnow().isoformat(),
            "event_type": data.get("event_type", "unknown"),
            "user_id": data.get("user_id", ""),
            "details": data  # Store full message as JSON
        }
        
        # Insert into BigQuery
        errors = client.insert_rows_json(table_id, [row])
        
        if errors:
            print(f"Errors inserting rows: {errors}")
            raise Exception(f"Failed to insert row: {errors}")
        
        print(f"Successfully processed {row['event_type']} event for user {row['user_id']}")
        
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")
        raise
    except Exception as e:
        print(f"Error processing message: {e}")
        raise