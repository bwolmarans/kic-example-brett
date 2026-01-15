# kix-example-brett

This is an example of using the Kong Ingress Controller to two different services, both on the same port.
The first service is echo, the second service is nginx, say as a simple web server.
Each service is in it's own namespace.

## This is in Minikube and we use Metallb

```
minikube addons enable metallb
❗  metallb is a 3rd party addon and is not maintained or verified by minikube maintainers, enable at your own risk.
❗  metallb does not currently have an associated maintainer.
    ▪ Using image quay.io/metallb/speaker:v0.9.6
    ▪ Using image quay.io/metallb/controller:v0.9.6
🌟  The 'metallb' addon is enabled

minikube profile list
┌──────────┬────────┬─────────┬──────────────┬─────────┬────────┬───────┬────────────────┬────────────────────┐
│ PROFILE  │ DRIVER │ RUNTIME │      IP      │ VERSION │ STATUS │ NODES │ ACTIVE PROFILE │ ACTIVE KUBECONTEXT │
├──────────┼────────┼─────────┼──────────────┼─────────┼────────┼───────┼────────────────┼────────────────────┤
│ minikube │ docker │ docker  │ 192.168.49.2 │ v1.34.0 │ OK     │ 1     │ *              │ *                  │
└──────────┴────────┴─────────┴──────────────┴─────────┴────────┴───────┴────────────────┴────────────────────┘

minikube addons configure metallb
-- Enter Load Balancer Start IP: 192.168.49.100
-- Enter Load Balancer End IP: 192.168.49.101
    ▪ Using image quay.io/metallb/speaker:v0.9.6
    ▪ Using image quay.io/metallb/controller:v0.9.6
✅  metallb was successfully configured

k expose deployment nginx-deployment --type LoadBalancer --port 80 --target-port 80
service/nginx-deployment exposed
# this requires uncommenting the nodeport part of NGINX deplyoment yaml

k get svc -A
NAMESPACE     NAME               TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                  AGE
default       kubernetes         ClusterIP      10.96.0.1       <none>           443/TCP                  102m
default       nginx-deployment   LoadBalancer   10.104.218.54   192.168.49.100   80:30864/TCP             4s
kube-system   kube-dns           ClusterIP      10.96.0.10      <none>           53/UDP,53/TCP,9153/TCP   102m


curl 192.168.49.100
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```
## Now add KIC (using "from GUI" instructions)
When we do this, it will actually create another LoadBalancer service on 192.168.49.101, in my examples below, it uses 192.168.49.100 because I did not actually do the MetalLB method before capturing that output.

```
k create ns kong
helm repo add kong https://charts.konghq.com
helm repo update
helm install kong kong/ingress -n kong --values kic-to-konnect-ingresscontroller-and-gateway.yaml
```
### Now add the echo and nginx deployments and services
```
k create ns echo
k apply -f echo-deployment-and-service 
k creat ns nginx
k apply -f nginx-deployment-and-service
```
### Now add the respective ingresses and check the services exist
```
k apply -f kic-ingress-for-echo.yaml
k apply -f kic-ingress-for-nginx.yaml
k get svc -A
NAMESPACE     NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                               AGE
default       kubernetes                           ClusterIP      10.96.0.1        <none>           443/TCP                               5d16h
echo          echo                                 ClusterIP      10.97.20.125     <none>           1025/TCP,1026/TCP,8080/TCP,1030/TCP   5m37s
kong          kong-controller-metrics              ClusterIP      10.110.148.227   <none>           10255/TCP,10254/TCP                   6m43s
kong          kong-controller-validation-webhook   ClusterIP      10.107.14.43     <none>           443/TCP                               6m43s
kong          kong-gateway-admin                   ClusterIP      None             <none>           8444/TCP                              6m42s
kong          kong-gateway-proxy                   LoadBalancer   10.103.8.238     192.168.49.100   80:31142/TCP,443:31781/TCP            6m42s
kube-system   kube-dns                             ClusterIP      10.96.0.10       <none>           53/UDP,53/TCP,9153/TCP                5d16h
nginx         nginx                                ClusterIP      10.96.176.190    <none>           8080/TCP                              4m52s
```
### Test
```
curl 192.168.49.100
{
  "message":"no Route matched with those values",
  "request_id":"01051e5d5aa7d823e361eb4bfd4fa35b"
}

curl 192.168.49.100/echo
Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-mdlkx.
In namespace echo.
With IP address 10.244.0.21.


curl 192.168.49.100/nginx
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
 
```
## Rate Limit Plugin
```
k apply -f create-rate-limit-plugin.yaml 
kongplugin.configuration.konghq.com/rate-limit-5-min created

k annotate -n kong service echo konghq.com/plugins=rate-limit-5-min
service/echo annotated

for i in {1..10}; do curl 192.168.49.100/echo; done;
Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.

Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.

Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.

Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.

Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.

{
  "message":"API rate limit exceeded",
  "request_id":"915b65533f446f58813b076a9059646c"
}
```
