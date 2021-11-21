locals {
  kubeadm-config = <<KUBEADMCONFIG
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
apiServer:
  extraArgs:
    cloud-provider: aws
clusterName: ${var.cluster["cluster_name"]}
kubernetesVersion: stable
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"    
controlPlaneEndpoint: "${aws_lb.k8snlb.dns_name}:6443"
networking:
  dnsDomain: cluster.local
  podSubnet: ${var.vpc_cidr}
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
KUBEADMCONFIG

}

output "nat_public_ips" {
  value       = ["${module.vpc.nat_public_ips}"]
  description = "List of public Elastic IPs created for AWS NAT Gateway"
}

output "private_subnets" {
  value       = ["${module.vpc.private_subnets}"]
  description = "List of private subnets ids."
}

output "public_subnets" {
  value       = ["${module.vpc.public_subnets}"]
  description = "List of public subnets ids."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "Cluster VPC id"
}

output "kubeadm-config" {
  value = local.kubeadm-config
}

