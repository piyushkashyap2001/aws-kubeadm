#!/bin/bash

# Prevent interactive dialogs to popup in non interactive shell
# See https://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
export DEBIAN_FRONTEND=noninteractive

# Letting iptable to see bridge traffic

## Load kernel module
modprobe br_netfilter
cat <<EOF > /etc/modules
br_netfilter
EOF

## Setup bridge flags
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

## Reload system
sysctl --system

# Install Docker CE
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

## Install Docker CE.
apt-get update && apt-get install -y \
  containerd.io=1.2.13-1 \
  docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker



# Install kubeadm kubectl and kubelet
## Add Repository
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

## Install kubelet kubeadm kubectl 
# To install specific versions: 
# apt-get install -qy kubelet=<version> kubectl=<version> kubeadm=<version>
# All versions are avaialble at: 
# curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}'
# Example: 1.17.4-00

apt-get update
apt-get install -y kubelet kubectl kubeadm awscli jq  #awscli and jq packages are required to dynamically generate join command for worker nodes
apt-mark hold kubelet kubeadm kubectl