# Kubernetes 1.21.1 on Windows + VirtualBox with Vagrant and Ansible

An example setup of HA Kubernetes cluster with WSL2 + Vagrant + Ansible on your home PC.

## Prerequisities

- 8 core CPU (for 3 control plane, 2 data plane nodes and 1 load balancer)
- 25GB RAM (for 3 control plane, 2 data plane nodes and 1 load balancer)
- [Install VirtualBox for Windows](https://www.virtualbox.org/wiki/Downloads)
- [Install WSL and Ubuntu 20.04](https://docs.microsoft.com/en-us/windows/wsl/install-win10#manual-installation-steps)
  - [Install Vagrant](https://www.vagrantup.com/docs/other/wsl)
  - [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu)
  - [Install `kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management)

## Create Kubernetes cluster

- Update `VAGRANT_SSH_HOST` in `.wsl-env` with primary IP of your host
- Open WSL shell (keep shell open for subsequent commands) and configure Vagrant for WSL

  ```sh
  source .wsl-env
  ```

- Provision VMs

  ```sh
  vagrant up
  ```

- Navigate to HAProxy stats at http://192.168.50.5:8404/stats

  You should see `apiserver` backends turning green in load balancer as the cluster is being provisioned.

  ![](haproxy-apiserver-lb.png)

- Copy `kubeconfig` to host machine

  ```sh
  vagrant ssh k8s-cp-1 -c 'mkdir -p /vagrant/.kube && cp .kube/config /vagrant/.kube/config'
  ```

  ⚠️ `/vagrant/.kube/config` will contain credentials for `kubernetes-admin` account.

- Check out Kubernetes nodes and pods

  ```sh
  export KUBECONFIG=$(pwd)/.kube/config
  kubectl get nodes
  kubectl get pods -A
  ```

## Install MetalLB load-balancer (optional)

If you want to create Kubernetes Services of type LoadBalancer then you need a network load-balancer for bare metal Kubernetes cluster since Kubernetes itself does not offer implementation of network load-balancer.

[MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols](https://metallb.org/).

- Install and configure MetalLB v0.10.2 in Kubernetes cluster.

  ```sh
  pushd metallb && sh install-metallb.sh && popd
  ```

- Deploy example web app and create load-balancer Service

  ```
  kubectl run hello-kubernetes --image=paulbouwer/hello-kubernetes:1 --port=8080 --labels=app=hello-kubernetes
  kubectl create service loadbalancer hello-kubernetes --tcp=80:8080
  ```

- Get load-balancer IP for web app

  ```
  kubectl get service hello-kubernetes -o 'jsonpath={.status.loadBalancer.ingress[0].ip}'
  ```

  Navigate to web app at http://\<load-balancer-ip\>.
