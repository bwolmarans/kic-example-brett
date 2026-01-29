# kic-example-brett

This is an example of using the Kong Ingress Controller to two different services, both on the same port.
The first service is echo, the second service is nginx, say as a simple web server.
Each service is in it's own namespace.  This also is part of onboarding.

## Tested with both Minikube and K3D
### With both, we use Metallb
###
### First, Metallb.  If using K3D look further down.
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

```
## Now with K3D
```
k3d cluster create cluster1   --k3s-arg "--disable=servicelb@server:0"   --k3s-arg "--disable=traefik@server:0"
docker network inspect k3d-cluster1 | grep Subnet
# the metallb-address-pool-for-k3d.yaml should have the 172.18.x.x subnet
k apply -f metallb-address-pool-for-k3d.yaml 
```
### Now a simple NGINX service on NodePort
```
k create ns nginx
k apply -f nginx-nodeport-deployment-and-service.yaml
k get svc -A
```
```
NAMESPACE     NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP                  5d17h
kube-system   kube-dns     ClusterIP   10.96.0.10      <none>        53/UDP,53/TCP,9153/TCP   5d17h
nginx         nginx        NodePort    10.97.204.222   <none>        8080:31572/TCP           72s
```
```
k get nodes -o wide
```
```
NAME       STATUS   ROLES           AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
minikube   Ready    control-plane   5d17h   v1.34.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   5.15.0-164-generic   docker://28.4.0
```
```
curl 192.168.49.2:31572
```
```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
...
```
```
# cleanup
k delete ns nginx
```
### Now the same NGINX deployment only, without any nodeport service, instead we will use MetalLB
```
k create ns nginx
k apply -f nginx-deployment.yaml 
deployment.apps/nginx created
k expose deployment nginx --type LoadBalancer --port 8888 --target-port 80 -n nginx
```
```
service/nginx exposed
```
```
k get svc -A
```
```
NAMESPACE     NAME         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                  AGE
default       kubernetes   ClusterIP      10.96.0.1        <none>           443/TCP                  5d17h
kube-system   kube-dns     ClusterIP      10.96.0.10       <none>           53/UDP,53/TCP,9153/TCP   5d17h
nginx         nginx        LoadBalancer   10.103.120.235   192.168.49.100   8888:31720/TCP           9s
```
```
curl 192.168.49.100:8888
```
```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
...
```
```
# cleanup 
k delete ns nginx
```

## Now add KIC (using "from GUI" instructions)
When we do this, it will actually create another LoadBalancer service on 192.168.49.101, in my examples below, it uses 192.168.49.100 because I did not actually do the MetalLB method before capturing that output.

```
# set env vars for your KONNECT cert and key TLS_CERT and TLS_KEY 
k create ns kong
# first export your Konnect cert and key to TLS_CERT and TLS_KEY env vars 
kubectl create secret tls konnect-client-tls -n kong --cert=<(echo "$TLS_CERT")   --key=<(echo "$TLS_KEY")
helm repo add kong https://charts.konghq.com
helm repo update
# now edit kic-to-konnect-ingresscontroller-and-gw-helm-chart.yaml and put in your control plane id, and a couple of other things. These are best found in the Konnect GUI itself by going to install KIC and selecting the Helm method)
helm install kong kong/ingress -n kong --values kic-to-konnect-ingresscontroller-and-gw-helm-chart.yaml
```
### Now add the echo and nginx deployments and services
```
k create ns echo
k apply -f echo-deployment-and-service.yaml
k create ns nginx
k apply -f nginx-deployment-and-service.yaml
```
### Now add the respective ingresses and check the services exist
```
k apply -f kic-ingress-for-echo.yaml
k apply -f kic-ingress-for-nginx.yaml
k get svc -A
```
```
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
```

```
{
  "message":"no Route matched with those values",
  "request_id":"01051e5d5aa7d823e361eb4bfd4fa35b"
}
```

```
curl 192.168.49.100/echo
```
```
Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-mdlkx.
In namespace echo.
With IP address 10.244.0.21.
```
```
curl 192.168.49.100/nginx
```
```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
... 
```
## Rate Limit Plugin
```
k apply -f create-rate-limit-plugin.yaml 
```
```
kongplugin.configuration.konghq.com/rate-limit-5-min created
```
```
# note you must annote it using the ns of the service, so here it is scoped to ns echo
k annotate -n echo service echo konghq.com/plugins=rate-limit-5-min
```
```
service/echo annotated
```
```
for i in {1..10}; do curl 192.168.49.100/echo; done;
```
```
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
