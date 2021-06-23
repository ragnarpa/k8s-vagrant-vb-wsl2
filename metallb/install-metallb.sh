# Prepare kube-proxy config for MetalLB.
kubectl get configmap kube-proxy -n kube-system -o yaml |
    sed -e "s/strictARP: false/strictARP: true/" |
    kubectl apply -f - -n kube-system

# Restart kube-proxy.
kubectl get pods -n kube-system -oname | grep kube-proxy | xargs kubectl delete -n kube-system

# Install MetalLB.
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml

# Configure MetalLB. MetalLB is idle until configured.
kubectl apply -f metallb-config.yml
