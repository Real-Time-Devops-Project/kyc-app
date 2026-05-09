"""
JIRA Incident Formatter

This module provides utilities to format incident descriptions for JIRA,
including converting URLs into clickable links.
"""

import json
import logging
import re
from typing import Any, Dict, List, Union
from urllib.parse import urlparse

def format_description(description: str) -> str:
    """
    Reorganize and format JIRA description with sections and clickable links.
    """
    lines = description.split("\n")

    # Human-readable labels for URL links
    url_label_mapping = {
        "pagerdutyurl": "Pagerduty Incident",
        "alertqueryurl": "Query to fetch raw Alert data",
        "defenderurl": "Defender Portal Incident",
        "incidenturl": "Sentinel Incident",
    }

    description_text = None
    defender_id = None
    url_links = []
    entities = {}
    incident_arm_id = None
    severity = None
    other_content = []
    standalone_urls = []

    url_pattern = r"^([a-zA-Z0-9_]+):\s+(https?://\S+)$"
    field_pattern = r"^([a-zA-Z0-9_]+):\s*(.*)$"

    in_entities = False
    current_entity_index = None
    entity_lines = []

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("http://") or stripped.startswith("https://"):
            if i > 0 and ":" in lines[i - 1] and lines[i - 1].strip().endswith(":"):
                pass
            else:
                standalone_urls.append(stripped)
                i += 1
                continue

        if stripped == "entities:":
            in_entities = True
            i += 1
            continue

        if in_entities:
            entity_index_match = re.match(r"^(\d+):\s*$", stripped)
            if entity_index_match:
                if current_entity_index is not None and entity_lines:
                    entities[current_entity_index] = entity_lines
                current_entity_index = entity_index_match.group(1)
                entity_lines = []
                i += 1
                continue

            exit_entity_fields = [
                "incidentarmid", "incidenturl", "severity",
                "alertqueryurl", "defenderincidentid", "defenderurl",
            ]

            if stripped and ":" in stripped:
                field_name = stripped.split(":")[0].lower()
                if field_name in exit_entity_fields:
                    if current_entity_index is not None and entity_lines:
                        entities[current_entity_index] = entity_lines
                    in_entities = False
                    current_entity_index = None
                    entity_lines = []
                    continue

            if current_entity_index is not None:
                if stripped:
                    entity_lines.append(line.rstrip())
                i += 1
                continue

        url_match = re.match(url_pattern, stripped)
        if url_match:
            field_name = url_match.group(1)
            url = url_match.group(2)
            if "armid" in field_name.lower():
                incident_arm_id = url
            else:
                label = url_label_mapping.get(field_name.lower(), field_name)
                url_links.append(f"- [{label}|{url}]")
            i += 1
            continue

        field_match = re.match(field_pattern, stripped)
        if field_match:
            field_name = field_match.group(1)
            value = field_match.group(2).strip()

            if field_name.lower() == "description":
                if value:
                    description_text = value
            elif field_name.lower() == "defenderincidentid":
                defender_id = f"defenderIncidentId: {value}"
            elif field_name.lower() == "severity":
                severity = f"severity: {value}"
            elif "armid" in field_name.lower():
                incident_arm_id = value
            elif field_name.lower() == "entities":
                pass
            else:
                if value and not value.startswith("http"):
                    other_content.append(f"{field_name}: {value}")
            i += 1
            continue

        if stripped:
            other_content.append(line)
        i += 1

    if current_entity_index is not None and entity_lines:
        entities[current_entity_index] = entity_lines

    result = []
    if description_text:
        result.extend([description_text, ""])
    if defender_id:
        result.extend([defender_id, ""])
    if severity:
        result.extend([severity, ""])

    if url_links or standalone_urls:
        result.extend(["h3. Useful links", ""])
        for url in standalone_urls:
            parsed = urlparse(url)
            hostname = parsed.hostname or ""
            if hostname == "pagerduty.com" or hostname.endswith(".pagerduty.com"):
                result.append(f"- [{url_label_mapping['pagerdutyurl']}|{url}]")
            else:
                domain = re.search(r"https?://([^/]+)", url)
                if domain:
                    result.append(f"- [{domain.group(1)}|{url}]")
                else:
                    result.append(f"- [link|{url}]")
        result.extend(url_links)
        result.append("")

    if entities:
        result.extend(["h3. Mapped Entities", ""])
        for entity_index in sorted(entities.keys(), key=int):
            result.extend([f"Entity {entity_index}:", "{code}"])
            for entity_line in entities[entity_index]:
                result.append(entity_line)
            result.extend(["{code}", ""])

    if other_content:
        for line in other_content:
            if line.strip():
                result.append(line)
        result.append("")

    if incident_arm_id:
        result.extend(["h3. For Tracking", "", f"incidentArmID: {incident_arm_id}"])

    formatted = "\n".join(result).strip()
    formatted = re.sub(r"\n{3,}", "\n\n", formatted)
    return formatted

def convert_plaintext_to_adf(plaintext: str) -> Dict[str, Any]:
    lines = plaintext.split("\n")
    content: List[Dict[str, Any]] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue

        if stripped.startswith("h3. "):
            header_text = stripped[4:]
            content.append({
                "type": "heading",
                "attrs": {"level": 3},
                "content": [{"type": "text", "text": header_text}],
            })
            i += 1
            continue

        if stripped == "{code}":
            code_lines = []
            i += 1
            while i < len(lines) and lines[i].strip() != "{code}":
                code_lines.append(lines[i])
                i += 1
            code_text = "\n".join(code_lines)
            content.append({
                "type": "codeBlock",
                "attrs": {},
                "content": [{"type": "text", "text": code_text}] if code_text else [],
            })
            i += 1
            continue

        if stripped.startswith("- "):
            list_items: List[Dict[str, Any]] = []
            while i < len(lines) and lines[i].strip().startswith("- "):
                item_text = lines[i].strip()[2:]
                link_match = re.match(r"\[([^\]]+)\|([^\]]+)\]", item_text)
                if link_match:
                    label = link_match.group(1)
                    url = link_match.group(2)
                    list_items.append({
                        "type": "listItem",
                        "content": [{
                            "type": "paragraph",
                            "content": [{
                                "type": "text",
                                "text": label,
                                "marks": [{"type": "link", "attrs": {"href": url}}]
                            }],
                        }],
                    })
                else:
                    list_items.append({
                        "type": "listItem",
                        "content": [{
                            "type": "paragraph",
                            "content": [{"type": "text", "text": item_text}],
                        }],
                    })
                i += 1
            content.append({"type": "bulletList", "content": list_items})
            continue

        content.append({
            "type": "paragraph",
            "content": [{"type": "text", "text": stripped}],
        })
        i += 1

    return {"version": 1, "type": "doc", "content": content}

def generate_formatted_description(original_description: str, adf_output: bool = False) -> Union[str, Dict[str, Any]]:
    logging.info("---- Original Description (Raw) ----")
    logging.info(original_description)

    normalized_description = original_description.replace("\r\n", "\n")

    formatted_description = format_description(normalized_description)

    if normalized_description.strip() == formatted_description.strip():
        if adf_output:
            return convert_plaintext_to_adf(original_description)
        return original_description

    if adf_output:
        adf_document = convert_plaintext_to_adf(formatted_description)
        return adf_document

    return formatted_description
