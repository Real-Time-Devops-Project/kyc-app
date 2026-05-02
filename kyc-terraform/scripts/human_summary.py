import json
import sys

def get_category(resource_type):
    if resource_type.startswith('aws_eks') or resource_type.startswith('kubernetes'):
        return "🚀 EKS Kubernetes Cluster"
    elif resource_type.startswith('aws_db') or resource_type.startswith('aws_docdb') or resource_type.startswith('aws_elasticache') or resource_type.startswith('aws_rds'):
        return "🗄️ Databases & Caching"
    elif resource_type.startswith('aws_vpc') or resource_type.startswith('aws_subnet') or resource_type.startswith('aws_route') or 'gateway' in resource_type or 'security_group' in resource_type or 'network_acl' in resource_type:
        return "🌐 Networking Infrastructure"
    elif resource_type.startswith('aws_iam') or resource_type.startswith('aws_kms') or 'waf' in resource_type:
        return "🔐 Identity & Security"
    elif resource_type.startswith('aws_s3') or resource_type.startswith('aws_cloudfront'):
        return "📦 Storage & Web Delivery"
    elif resource_type.startswith('aws_instance') or resource_type.startswith('aws_ami'):
        return "💻 Compute & Management"
    else:
        return "⚙️ General Infrastructure"

def get_resource_friendly_name(rc):
    # Try to get physical name or Name tag, otherwise fallback to logical name
    logical_name = rc.get('name', 'unknown')
    res_type = rc.get('type', '')
    
    after = rc.get('change', {}).get('after', {})
    if not after:
        return f"{res_type}.{logical_name}"
        
    # Check for tags -> Name
    tags = after.get('tags', {})
    if isinstance(tags, dict) and 'Name' in tags:
        return f"{tags['Name']} ({res_type})"
        
    # Check for 'name' or 'identifier'
    if 'name' in after and after['name']:
        return f"{after['name']} ({res_type})"
    if 'identifier' in after and after['identifier']:
        return f"{after['identifier']} ({res_type})"
        
    return f"{logical_name} ({res_type})"

def main():
    if len(sys.argv) < 2:
        print("Usage: python human_summary.py <path_to_tfplan.json> [region]")
        sys.exit(1)

    plan_path = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    
    try:
        with open(plan_path, 'r') as f:
            plan = json.load(f)
    except Exception as e:
        print(f"Error reading {plan_path}: {e}")
        sys.exit(1)

    resource_changes = plan.get('resource_changes', [])
    
    # Structure: { category_name: { "create": [], "update": [], "delete": [], "replace": [] } }
    categories = {}

    for rc in resource_changes:
        actions = rc.get('change', {}).get('actions', [])
        # Ignore no-op and read
        if not actions or actions == ["no-op"] or actions == ["read"]:
            continue
            
        action_type = "unknown"
        if "create" in actions and "delete" in actions:
            action_type = "replace"
        elif "create" in actions:
            action_type = "create"
        elif "delete" in actions:
            action_type = "delete"
        elif "update" in actions:
            action_type = "update"
            
        if action_type == "unknown":
            continue

        res_type = rc.get('type', '')
        cat = get_category(res_type)
        friendly_name = get_resource_friendly_name(rc)
        
        if cat not in categories:
            categories[cat] = {"create": [], "update": [], "delete": [], "replace": []}
            
        categories[cat][action_type].append(friendly_name)

    if not categories:
        print("No infrastructure changes required.")
        return

    print("### 🚀 Infrastructure Deployment Summary\n")
    print("This deployment will make the following high-level changes to your AWS environment.\n")
    print("| Category | Action | Region | Resource List |")
    print("|---|---|---|---|")

    action_emojis = {
        "create": "✨ Create",
        "update": "🔄 Update",
        "replace": "♻️ Replace",
        "delete": "🗑️ Delete"
    }

    for cat, actions in categories.items():
        for action_key, resources in actions.items():
            if resources:
                count = len(resources)
                action_text = f"{action_emojis[action_key]} ({count})"
                # Format resources list nicely, truncate if too long
                res_list_str = ", ".join([f"`{r}`" for r in resources])
                if len(res_list_str) > 200:
                    res_list_str = res_list_str[:197] + "..."
                
                print(f"| **{cat}** | {action_text} | {region} | {res_list_str} |")

    print("\n---\n")
    print("### ✅ Pre-Deployment Best Practice Checklist")
    print("Before approving this PR, please verify the following:")
    print("- [ ] **Cost Impact:** Have these new resources been budgeted for this environment?")
    print("- [ ] **Security:** Are there any new public endpoints or overly permissive IAM roles being created?")
    print("- [ ] **Compliance:** Does this change align with our Checkov/security compliance tracker?")
    print("- [ ] **Downtime:** Will any of these updates (like database engine upgrades or cluster replacements) cause application downtime?")
    print("- [ ] **Dependencies:** Are there any external dependencies (like DNS cutovers or third-party integrations) required after this applies?")

if __name__ == "__main__":
    main()
