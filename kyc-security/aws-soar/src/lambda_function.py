import json
import logging
import traceback

from enrichment import incident_enrichment_handler
from formatter import generate_formatted_description

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda entry point handling multiple endpoints via Lambda Function URLs
    or API Gateway.
    """
    try:
        path = event.get('rawPath', event.get('path', ''))
        method = event.get('requestContext', {}).get('http', {}).get('method', 'POST')
        
        # Parse body
        body = {}
        if 'body' in event and event['body']:
            try:
                body = json.loads(event['body'])
            except Exception as e:
                logger.error(f"Failed to parse body: {e}")
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Invalid JSON body'})
                }

        logger.info(f"Received request for path: {path} with method: {method}")

        # Route: /incident-enrichment
        if path.endswith('/incident-enrichment') and method == 'POST':
            incident_id = body.get('incidentId')
            if not incident_id:
                return {'statusCode': 400, 'body': json.dumps({'error': 'incidentId required'})}
            
            enrichment_data = incident_enrichment_handler(incident_id)
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(enrichment_data)
            }

        # Route: /incident-description-format
        elif path.endswith('/incident-description-format') and method == 'POST':
            issue_description = body.get('issueDescription', '')
            output_format = body.get('outputFormat', 'plaintext')
            output_adf = (output_format == 'adf')

            formatted_description = generate_formatted_description(
                issue_description,
                adf_output=output_adf
            )
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'formattedDescription': formatted_description})
            }

        # Route: /debug
        elif path.endswith('/debug'):
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Debug endpoint OK',
                    'path': path,
                    'method': method,
                    'headers': event.get('headers', {})
                })
            }

        # Default Not Found
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': f'Route not found: {path}'})
            }

    except Exception as e:
        logger.error(f"Unhandled exception: {str(e)}")
        logger.error(traceback.format_exc())
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
