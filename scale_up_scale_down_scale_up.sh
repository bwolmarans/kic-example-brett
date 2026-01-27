!#/bin/bash
echo ""
echo ""
echo "********************************************"
echo "Example of using Kong Gateway as an external Load Balancer"
echo ""
echo "Step 1: We will start by scaling up our app, update the upstreams"
echo "Step 2: Send traffic to Kong Gateway and see which apps are being hit"
echo "Step 3: Scale down the app and update upstreams"
echo "Step 4: Send traffic again to Kong Gatewy and see the reesult"
echo ""
sleep 10
echo "********************************************"
echo "Scaling Up to Three (3) Instances of the Application"
echo "********************************************"
sleep 3
kubectl apply -f ./3-separate-nginx-pods-and-services.yaml -n default
sleep 3
echo "********************************************"
echo "Checking services"
echo "********************************************"
sleep 3
kubectl get svc -n default
sleep 3
echo "********************************************"
echo "Running our \"controller\" to query the K8s API, find the services, and update the external Kong Gw to match the scaling."
echo "********************************************"
sleep 3
python3 k8s_api_python_example.py
sleep 4
echo ""
echo "********************************************"
echo "Check the Kong Gateway in the UI"
echo "********************************************"
echo ""
sleep 10
echo ""
echo "********************************************"
echo "Running traffic through the external Kong Gw (acting as the LoadBalancer)"
echo "********************************************"
sleep 3
for i in {1..10}; do curl 127.0.0.1:8000/1; done
sleep 3
echo "********************************************"
echo "Scaling down to One (1) instance of the Application"
echo "********************************************"
sleep 3
kubectl delete svc service-pod-2 -n default
kubectl delete svc service-pod-3 -n default
sleep 3
echo "********************************************"
echo "Checking services"
echo "********************************************"
sleep 3
kubectl get svc -n default
sleep 3
echo "********************************************"
echo "Running our \"controller\" to query the K8s API, find the services, and update the external Kong Gw to match the scaling."
echo "********************************************"
sleep 3
python3 k8s_api_python_example.py
sleep 4
echo ""
echo "********************************************"
echo "Check the Kong Gateway in the UI"
echo "********************************************"
echo ""
sleep 10
echo ""
echo "********************************************"
echo "Running traffic through the external Kong Gw (acting as the LoadBalancer)"
echo "********************************************"
sleep 3
for i in {1..10}; do curl 127.0.0.1:8000/1; done
echo "********************************************"
echo ""
echo "********************************************"
echo "Scaling Up to Three (3) Instances of the Application"
echo "********************************************"
sleep 3
kubectl apply -f ./3-separate-nginx-pods-and-services.yaml -n default
sleep 3
echo "********************************************"
echo "Checking services"
echo "********************************************"
sleep 3
kubectl get svc -n default
sleep 3
echo "********************************************"
echo "Running our \"controller\" to query the K8s API, find the services, and update the external Kong Gw to match the scaling."
echo "********************************************"
sleep 3
python3 k8s_api_python_example.py
sleep 4
echo ""
echo "********************************************"
echo "Check the Kong Gateway in the UI"
echo "********************************************"
echo ""
sleep 10
echo ""
echo "********************************************"
echo "Running traffic through the external Kong Gw (acting as the LoadBalancer)"
echo "********************************************"
sleep 3
for i in {1..10}; do curl 127.0.0.1:8000/1; done
sleep 3