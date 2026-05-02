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

def main():
    if len(sys.argv) < 2:
        print("Usage: python human_summary.py <path_to_tfplan.json>")
        sys.exit(1)

    plan_path = sys.argv[1]
    try:
        with open(plan_path, 'r') as f:
            plan = json.load(f)
    except Exception as e:
        print(f"Error reading {plan_path}: {e}")
        sys.exit(1)

    resource_changes = plan.get('resource_changes', [])
    
    # Structure: { category_name: { "create": 0, "update": 0, "delete": 0 } }
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
        
        if cat not in categories:
            categories[cat] = {"create": 0, "update": 0, "delete": 0, "replace": 0}
            
        categories[cat][action_type] += 1

    if not categories:
        print("No infrastructure changes required.")
        return

    print("### 🚀 Infrastructure Deployment Summary\n")
    print("This deployment will make the following high-level changes to your AWS environment:\n")

    for cat, counts in categories.items():
        print(f"#### {cat}")
        if counts["create"] > 0:
            print(f"- ✨ **Creating** {counts['create']} resource(s)")
        if counts["update"] > 0:
            print(f"- 🔄 **Updating** {counts['update']} resource(s)")
        if counts["replace"] > 0:
            print(f"- ♻️ **Replacing** {counts['replace']} resource(s)")
        if counts["delete"] > 0:
            print(f"- 🗑️ **Deleting** {counts['delete']} resource(s)")
        print("")

if __name__ == "__main__":
    main()
