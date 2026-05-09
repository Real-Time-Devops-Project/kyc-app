import gzip
import base64
import os
from datetime import datetime, timedelta, timezone

# Read Tenant ID from environment variable injected by AWS Lambda
TENANT_ID = os.environ.get("TENANT_ID", "default-tenant-id")

def generate_alert_raw_data_query_url(incident_id: str) -> str:
    query = f'ExtractIncidentRawLogs("{incident_id}")'

    utf16_bytes = query.encode("utf-16-le")
    compressed = gzip.compress(utf16_bytes)
    encoded = base64.b64encode(compressed).decode("utf-8")

    # Bit of a hack to get around the timepicker dropdown in the Defender UI.
    # This ensures the query always finds the incident, even if it is an old link.
    now = datetime.now(timezone.utc)
    from_date = now - timedelta(days=730)
    to_date = now + timedelta(days=365)

    from_date_str = from_date.strftime("%Y-%m-%d")
    to_date_str = to_date.strftime("%Y-%m-%d")

    return (
        f"https://security.microsoft.com/v2/advanced-hunting?"
        f"query={encoded}&tid={TENANT_ID}"
        f"&fromDate={from_date_str}&toDate={to_date_str}"
    )

def generate_defender_incident_url(incident_id: str) -> str:
    return (
        f"https://security.microsoft.com/incident2/{incident_id}/overview?"
        f"tid={TENANT_ID}"
    )

def incident_enrichment_handler(incident_id: str) -> dict:
    enrichment = {
        "xdr_alert_raw_data_query_url": generate_alert_raw_data_query_url(incident_id),
        "defender_incident_url": generate_defender_incident_url(incident_id),
    }

    return enrichment
