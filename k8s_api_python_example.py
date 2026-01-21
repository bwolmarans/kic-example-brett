from kubernetes import client, config
import requests
import json
import os

def main():
    # Load Kubeconfig file
    config.load_kube_config()

    # Initialize the CoreV1Api client
    v1 = client.CoreV1Api()
    
    namespace = "default"

    print(f"Listing pods in namespace '{namespace}':")
    # Call the list_namespaced_pod method
    ret = v1.list_namespaced_pod(namespace=namespace)

    print("IP\tNAMESPACE\tNAME")
    for i in ret.items:
        print("%s\t%s\t%s" % (i.status.pod_ip, i.metadata.namespace, i.metadata.name))

    print("\n" + "="*50)
    print(f"NodePort Ports in namespace '{namespace}':")
    # List services in the specific namespace and filter for NodePort type
    services = v1.list_namespaced_service(namespace=namespace)
    nodeports = []
    for service in services.items:
        if service.spec.type == "NodePort":
            for port in service.spec.ports:
                nodeports.append(port.node_port)
                print(f"Service: {service.metadata.name} (Namespace: {service.metadata.namespace}) - NodePort: {port.node_port}")
    
    if not nodeports:
        print("No NodePort services found")
    
    print(f"\nNodePort Array: {nodeports}")

    print("\n" + "="*50)
    print("Cluster Node IP Addresses:")
    # List all nodes and extract their IP addresses
    nodes = v1.list_node(watch=False)
    node_ips = []
    for node in nodes.items:
        for address in node.status.addresses:
            if address.type in ["ExternalIP", "InternalIP"]:
                node_ips.append(address.address)
                print(f"Node: {node.metadata.name} - {address.type}: {address.address}")
    
    print(f"\nNode IPs Array: {node_ips}")

    print("\n" + "="*50)
    print("Kong Konnect API Calls:")
    
    # Get control plane and upstream IDs from environment variables
    control_plane_id = os.getenv('KONG_CONTROL_PLANE_ID')
    upstream_id = os.getenv('KONG_UPSTREAM_ID')
    if not control_plane_id or not upstream_id:
        print("ERROR: KONG_CONTROL_PLANE_ID and/or KONG_UPSTREAM_ID environment variables not set")
        return
    
    # Make REST calls to Kong Konnect API using node IPs and NodePorts
    url = f"https://us.api.konghq.com/v2/control-planes/{control_plane_id}/core-entities/upstreams/{upstream_id}/targets"
    
    # Get bearer token from environment variable
    bearer_token = os.getenv('KONG_BEARER_TOKEN')
    if not bearer_token:
        print("ERROR: KONG_BEARER_TOKEN environment variable not set")
        return
    
    headers = {
        "accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {bearer_token}"
    }
    
    # Get existing targets
    print("\nFetching existing targets...")
    try:
        response = requests.get(url, headers=headers)
        existing_targets = []
        existing_targets_with_ids = []
        if response.status_code == 200:
            targets_data = response.json()
            # Extract target names/addresses from the response
            if 'data' in targets_data:
                for target in targets_data['data']:
                    target_address = target.get('target')
                    target_id = target.get('id')
                    existing_targets.append(target_address)
                    existing_targets_with_ids.append({"target": target_address, "id": target_id})
            print(f"Existing targets: {existing_targets}")
        else:
            print(f"Could not fetch existing targets. Status: {response.status_code}")
    except Exception as e:
        print(f"Error fetching existing targets: {e}")
        existing_targets = []
        existing_targets_with_ids = []
    
    # Create list of desired targets (node_ip:port combinations)
    desired_targets = []
    for node_ip in node_ips:
        for port in nodeports:
            desired_targets.append(f"{node_ip}:{port}")
    
    print(f"\nDesired targets: {desired_targets}")
    
    print(f"\nMaking requests using node IPs and NodePorts:")
    targets_added = 0
    targets_skipped = 0
    targets_deleted = 0
    
    for node_ip in node_ips:
        for port in nodeports:
            target = f"{node_ip}:{port}"
            
            # Check if target already exists
            if target in existing_targets:
                print(f"\nTarget: {target} - SKIPPED (already exists)")
                targets_skipped += 1
                continue
            
            data = {
                "target": target,
                "weight": 100
            }
            
            try:
                response = requests.post(url, headers=headers, json=data)
                print(f"\nTarget: {target}")
                print(f"Status Code: {response.status_code}")
                if response.status_code in [200, 201]:
                    print(f"Success: {json.dumps(response.json(), indent=2)}")
                    targets_added += 1
                else:
                    print(f"Response: {response.text}")
            except Exception as e:
                print(f"\nError making request for {target}: {e}")
    
    # Delete targets that are not in the desired list
    print(f"\n" + "="*50)
    print("Checking for targets to delete...")
    for target_info in existing_targets_with_ids:
        target_address = target_info.get('target')
        target_id = target_info.get('id')
        
        if target_address not in desired_targets:
            delete_url = f"{url}/{target_id}"
            try:
                response = requests.delete(delete_url, headers=headers)
                print(f"\nDeleting Target: {target_address} (ID: {target_id})")
                print(f"Status Code: {response.status_code}")
                if response.status_code in [200, 204]:
                    print(f"Successfully deleted")
                    targets_deleted += 1
                else:
                    print(f"Response: {response.text}")
            except Exception as e:
                print(f"\nError deleting target {target_address}: {e}")
    
    print(f"\n" + "="*50)
    print(f"Summary: {targets_added} targets added, {targets_skipped} targets skipped, {targets_deleted} targets deleted")

if __name__ == "__main__":
    main()
