!#/bin/bash
echo "********************************************"
echo "Scaling Up to Three (3) Instances of the Application"
echo "********************************************"
sleep 3
kubectl apply -f ./3-separate-nginx-pods-and-services.yaml
sleep 3
echo "********************************************"
echo "Checking services"
echo "********************************************"
sleep 3
kubectl get svc -A
sleep 3
echo "********************************************"
echo "Running our \"controller\" to query the K8s API, find the services, and update the external Kong Gw to match the scaling."
echo "********************************************"
sleep 3
python3 k8s_api_python_example.py
sleep 6
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
kubectl delete svc service-pod-2
kubectl delete svc service-pod-3
sleep 3
echo "********************************************"
echo "Checking services"
echo "********************************************"
sleep 3
kubectl get svc -A
sleep 3
echo "********************************************"
echo "Running our \"controller\" to query the K8s API, find the services, and update the external Kong Gw to match the scaling."
echo "********************************************"
sleep 3
python3 k8s_api_python_example.py
sleep 6
echo "********************************************"
echo "Running traffic through the external Kong Gw (acting as the LoadBalancer)"
echo "********************************************"
sleep 3
for i in {1..10}; do curl 127.0.0.1:8000/1; done
echo "********************************************"
