# simple-nginx-k8s
```
bwolmarans@ubu:  

/simple-nginx-k8s$ k apply -f nginx-deployment-and-service.yaml  
deployment.apps/nginx-deployment created  
service/nginx-service created   
bwolmarans@ubu:\~/simple-nginx-k8s$ k get svc -a  
error: unknown shorthand flag: 'a' in -a  
See 'kubectl get --help' for usage.  
bwolmarans@ubu:~/simple-nginx-k8s$ k get svc -A  
NAMESPACE     NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE  
default       kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP                  3m16s  
default       nginx-service   NodePort    10.109.237.64   <none>        80:32157/TCP             5s  
kube-system   kube-dns        ClusterIP   10.96.0.10      <none>        53/UDP,53/TCP,9153/TCP   3m15s  
bwolmarans@ubu:\~/simple-nginx-k8s$ curl 10.109.237.64  
ç^C  
bwolmarans@ubu:\~/simple-nginx-k8s$  
bwolmarans@ubu:\~/simple-nginx-k8s$  
bwolmarans@ubu:\~/simple-nginx-k8s$ k get nodes -o wide  
NAME       STATUS   ROLES           AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME  
minikube   Ready    control-plane   4m26s   v1.34.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   5.15.0-164-generic   docker://28.4.0  
bwolmarans@ubu:\~/simple-nginx-k8s$ curl 192.168.49.2:32157  
<!DOCTYPE html>  
<html>  
<head>  
<title>Welcome to nginx!</title>  
<style>  
```

## Next we use Metallb

```
bwolmarans@ubu:~$ minikube addons enable metallb
❗  metallb is a 3rd party addon and is not maintained or verified by minikube maintainers, enable at your own risk.
❗  metallb does not currently have an associated maintainer.
    ▪ Using image quay.io/metallb/speaker:v0.9.6
    ▪ Using image quay.io/metallb/controller:v0.9.6
🌟  The 'metallb' addon is enabled
bwolmarans@ubu:~$ minikube profile list
┌──────────┬────────┬─────────┬──────────────┬─────────┬────────┬───────┬────────────────┬────────────────────┐
│ PROFILE  │ DRIVER │ RUNTIME │      IP      │ VERSION │ STATUS │ NODES │ ACTIVE PROFILE │ ACTIVE KUBECONTEXT │
├──────────┼────────┼─────────┼──────────────┼─────────┼────────┼───────┼────────────────┼────────────────────┤
│ minikube │ docker │ docker  │ 192.168.49.2 │ v1.34.0 │ OK     │ 1     │ *              │ *                  │
└──────────┴────────┴─────────┴──────────────┴─────────┴────────┴───────┴────────────────┴────────────────────┘
bwolmarans@ubu:~$ minikube addons configure metallb
-- Enter Load Balancer Start IP: 192.168.49.100
-- Enter Load Balancer End IP: 192.168.49.101
    ▪ Using image quay.io/metallb/speaker:v0.9.6
    ▪ Using image quay.io/metallb/controller:v0.9.6
✅  metallb was successfully configured
bwolmarans@ubu:~$
bwolmarans@ubu:~$
bwolmarans@ubu:~$
bwolmarans@ubu:~$ k expose deployment nginx-deployment --type LoadBalancer --port 80 --target-port 80
service/nginx-deployment exposed
bwolmarans@ubu:~$ k get svc -A
NAMESPACE     NAME               TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                  AGE
default       kubernetes         ClusterIP      10.96.0.1       <none>           443/TCP                  102m
default       nginx-deployment   LoadBalancer   10.104.218.54   192.168.49.100   80:30864/TCP             4s
kube-system   kube-dns           ClusterIP      10.96.0.10      <none>           53/UDP,53/TCP,9153/TCP   102m
bwolmarans@ubu:~$
bwolmarans@ubu:~$
bwolmarans@ubu:~$
bwolmarans@ubu:~$ curl 192.168.49.100
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```
## Now add KIC (using "from GUI" instructions)
```
helm install kong kong/ingress -n kong --values kic-to-konnect-ingresscontroller-and-gateway.yaml
kubectl apply -f https://developer.konghq.com/manifests/kic/echo-service.yaml -n kong
NAMESPACE     NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                               AGE
default       kubernetes                           ClusterIP      10.96.0.1       <none>           443/TCP                               2d15h
default       nginx-deployment                     LoadBalancer   10.104.218.54   192.168.49.100   80:30864/TCP                          2d13h
kong          echo                                 ClusterIP      10.106.67.51    <none>           1025/TCP,1026/TCP,1027/TCP,1030/TCP   2d13h
kong          kong-controller-metrics              ClusterIP      10.102.66.98    <none>           10255/TCP,10254/TCP                   2d13h
kong          kong-controller-validation-webhook   ClusterIP      10.103.190.78   <none>           443/TCP                               2d13h
kong          kong-gateway-admin                   ClusterIP      None            <none>           8444/TCP                              2d13h
kong          kong-gateway-proxy                   LoadBalancer   10.97.69.35     192.168.49.101   80:31160/TCP,443:30355/TCP            2d13h
kube-system   kube-dns                             ClusterIP      10.96.0.10      <none>           53/UDP,53/TCP,9153/TCP                2d15h

ubu$ export PROXY_IP=$(kubectl get svc --namespace kong kong-gateway-proxy -o jsonpath='{range .status.loadBalancer.ingress[0]}{@.ip}{@.hostname}{end}')
ubu$ echo $PROXY_IP

ubu$ curl 192.168.49.101
{
  "message":"no Route matched with those values",
  "request_id":"18b63d1dcc2f557d8709c432a2904f43"
}
ubu$ curl 192.168.49.101/echo
Welcome, you are connected to node minikube.
Running on Pod echo-79d4b9b8bc-vh85x.
In namespace kong.
With IP address 10.244.0.10.
```
## Rate Limit Plugin
```
ubu$ k apply -f create-rate-limit-plugin.yaml 
kongplugin.configuration.konghq.com/rate-limit-5-min created
ubu$ k annotate -n kong service echo konghq.com/plugins=rate-limit-5-min
service/echo annotated
ubu$ for i in {1..10}; do curl 192.168.49.101/echo; done;
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
