#!/bin/bash

# --- Load Kong Konnect environment variables ---
if [ -z "$KONG_BEARER_TOKEN" ] || [ -z "$KONG_CONTROL_PLANE_ID" ] || [ -z "$KONG_UPSTREAM_ID" ]; then
    echo "ERROR: Missing required environment variables:"
    [ -z "$KONG_BEARER_TOKEN" ] && echo "  - KONG_BEARER_TOKEN"
    [ -z "$KONG_CONTROL_PLANE_ID" ] && echo "  - KONG_CONTROL_PLANE_ID"
    [ -z "$KONG_UPSTREAM_ID" ] && echo "  - KONG_UPSTREAM_ID"
    exit 1
fi

# --- Dynamically get Minikube IP and Config Details ---

# Get the Minikube IP (replace 'minikube' with your profile name if different)
MINIKUBE_IP=$(minikube ip)
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
echo $KUBECONFIG_PATH

# Extract and decode CA, client cert, and client key
#grep 'certificate-authority-data:' "$KUBECONFIG_PATH" | awk '{print $2}' | base64 --decode > /tmp/ca.crt
CLIENT_CERT=$(grep 'client-certificate:' "$KUBECONFIG_PATH" | awk '{print $2}')
CLIENT_KEY=$(grep 'client-key:' "$KUBECONFIG_PATH" | awk '{print $2}')


# Get the API server URL (for port, usually 8443)
API_SERVER_URL=$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')

# Extract just the port if needed, otherwise use the full URL from above
# The URL from kubectl config view includes the port, e.g., https://192.168.49.2:8443
API_ENDPOINT="${API_SERVER_URL}/api/v1/pods"

# --- Make the authenticated API call using curl ---

echo "Attempting to curl Kubernetes API at $API_ENDPOINT..."
echo "$CLIENT_CERT"
echo "$CLIENT_KEY"
CA_CERT="${HOME}/.minikube/ca.crt"

#curl -v -s --cacert ~/.minikube/ca.crt --cert "$CLIENT_CERT" --key "$CLIENT_KEY" "$API_ENDPOINT" | jq '.'
curl -s --cacert "${CA_CERT}" --cert "${CLIENT_CERT}" --key "${CLIENT_KEY}" "${API_SERVER_URL}/api/v1/services" | \
jq '[.items[] | select(.spec.type == "NodePort") | .spec.ports[].nodePort]'

echo ""
echo "Cluster Node IP Addresses:"
curl -s --cacert "${CA_CERT}" --cert "${CLIENT_CERT}" --key "${CLIENT_KEY}" "${API_SERVER_URL}/api/v1/nodes" | \
jq '[.items[].status.addresses[] | select(.type=="ExternalIP" or .type=="InternalIP") | .address]'

# Note: The `jq` command is used here to format the JSON output for readability. 
# You may need to install 'jq' (e.g., 'brew install jq' or 'apt install jq')
# If you don't have jq, remove the pipe: curl ... "$API_ENDPOINT"

curl -X POST "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/consumer_groups/" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
  --data ' { "name": "my_group" } '
  
echo ""
echo ""
echo ""

curl -X GET "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/services" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" 
  
echo ""
echo ""
echo ""

curl -X PUT "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/services/d5605911-bc87-4d75-96a7-5da89670fa6d" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
  --data '{  "host": "example.internal",  "id": "49fd316e-c457-481c-9fc7-8079153e4f3c",  "name": "example-service",  "path": "/",  "port": 80,  "protocol": "http"}'
  
echo ""
echo ""
echo ""

curl -X POST "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/services" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
  --data '{  "host": "nginx-nodeport-service",  "name": "nginx-server-1",  "path": "/",  "port": 30119,  "protocol": "http"}'
  
echo ""
echo ""
echo ""

curl -X POST "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/services" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
  --data '{  "host": "nginx-nodeport-service",  "name": "nginx-server-2",  "path": "/",  "port": 31338,  "protocol": "http"}'
  
echo ""
echo ""
echo ""

curl -X PUT "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/upstreams/${KONG_UPSTREAM_ID}" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
  --data '{ \
  "algorithm": "round-robin", \
  "hash_fallback": "none", \
  "hash_on": "none", \
  "hash_on_cookie_path": "/", \
  "healthchecks": { \
    "active": { \
      "concurrency": 10, \
      "healthy": { \
        "http_statuses": [ \
          200, \
          302 \
        ], \
        "interval": 0, \
        "successes": 0 \
      }, \
      "http_path": "/", \
      "https_verify_certificate": true, \
      "timeout": 1, \
      "type": "http", \
      "unhealthy": { \
        "http_failures": 0, \
        "http_statuses": [ \
          429, \
          404, \
          500, \
          501, \
          502, \
          503, \
          504, \
          505 \
        ], \
        "interval": 0, \
        "tcp_failures": 0, \
        "timeouts": 0 \
      } \
    }, \
    "passive": { \
      "healthy": { \
        "http_statuses": [ \
          200, \
          201, \
          202, \
          203, \
          204, \
          205, \
          206, \
          207, \
          208, \
          226, \
          300, \
          301, \
          302, \
          303, \
          304, \
          305, \
          306, \
          307, \
          308 \
        ], \
        "successes": 0 \
      }, \
      "type": "http", \
      "unhealthy": { \
        "http_failures": 0, \
        "http_statuses": [ \
          429, \
          500, \
          503 \
        ], \
        "tcp_failures": 0, \
        "timeouts": 0 \
      } \
    }, \
    "threshold": 0 \
  }, \
  "id": "6eed5e9c-5398-4026-9a4c-d48f18a2431e", \
  "name": "api.example.internal", \
  "slots": 10000 \
}'

curl -X GET  \
  --url "https://us.api.konghq.com/v2/control-planes/${KONG_CONTROL_PLANE_ID}/core-entities/upstreams/${KONG_UPSTREAM_ID}/targets" \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${KONG_BEARER_TOKEN}" \
 
