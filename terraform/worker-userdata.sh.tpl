#!/bin/bash
set -o xtrace

# Setting hostname as required by kubeadm
sudo hostnamectl set-hostname \
$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)

# Find master nodes by given tag
instances=$(aws ec2 describe-instances --filters "Name=tag-value,Values=${tag_value}" --region ${region}  | jq -r ".Reservations[].Instances[].InstanceId")
echo "control plane instances- $${instances}"
instance=$(echo $${instances}| cut -d ' ' -f 1)

# Generate token required to join cluster
echo "working with instance- $${instance}. Generating token."
sh_command_id=$(aws ssm send-command \
    --instance-ids "$${instance}" \
    --document-name "AWS-RunShellScript" \
    --comment "Generate kubernetes token" \
    --parameters commands="kubeadm token generate" \
    --output text \
    --query "Command.CommandId" \
    --region ${region})
sleep 5
echo "Receiving token"
result=$(aws ssm list-command-invocations --command-id "$${sh_command_id}" --details --region ${region} | jq -j ".CommandInvocations[0].CommandPlugins[0].Output")
token=$(echo $${result}| cut -d ' ' -f 1)

#  Generate kubeadm join command, however we will not use this command to join the cluster. This is a hack, required to update cluster-info.yaml with JWS in data section of kubeadm configmap. We will instead pass a config file to kubeadm join command as we are providing extra paramater for kubelet (cloud-provider: aws)
echo "generating join command"
sh_command_id=$(aws ssm send-command \
    --instance-ids "$${instance}" \
    --document-name "AWS-RunShellScript" \
    --comment "Generate kubeadm command to join worker node to cluster" \
    --parameters commands="kubeadm token create $${token}  --print-join-command" \
    --output text \
    --query "Command.CommandId" \
    --region ${region})
sleep 10
echo "getting result"
result=$(aws ssm list-command-invocations --command-id "$${sh_command_id}" --details --region ${region} | jq -j ".CommandInvocations[0].CommandPlugins[0].Output")
echo "kubeadm join command ==> $${result}."

# Get controlplaneEndpoint 
sh_command_id=$(aws ssm send-command \
    --instance-ids "$${instance}" \
    --document-name "AWS-RunShellScript" \
    --comment "Fetch control plane endpoint" \
    --parameters commands="kubectl -n kube-system get cm kubeadm-config --kubeconfig /home/ubuntu/.kube/config -o yaml | grep controlPlaneEndpoint" \
    --output text \
    --query "Command.CommandId" \
    --region ${region})
sleep 10
echo "Fetching control plane endpoint"
result=$(aws ssm list-command-invocations --command-id "$${sh_command_id}" --details --region ${region} | jq -j ".CommandInvocations[0].CommandPlugins[0].Output")
endpoint=$(echo $${result}| awk '{print $2}')

# Generate sha
sh_command_id=$(aws ssm send-command \
    --instance-ids "$${instance}" \
    --document-name "AWS-RunShellScript" \
    --comment "Generating hash" \
    --parameters commands="openssl x509 -in /etc/kubernetes/pki/ca.crt -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256" \
    --output text \
    --query "Command.CommandId" \
    --region ${region})
sleep 10
echo "Generating hash"
result=$(aws ssm list-command-invocations --command-id "$${sh_command_id}" --details --region ${region} | jq -j ".CommandInvocations[0].CommandPlugins[0].Output")
hashValue=$(echo $${result} | awk '{print $2}')

# Generate worker node host name
hostname=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)

# Create a config file for worker nodes to join the cluster
cat <<EOF > /home/ubuntu/worker-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: "$${token}"
    apiServerEndpoint: "$${endpoint}"
    caCertHashes:
      - "sha256:$${hashValue}"
nodeRegistration:
  name: "$${hostname}"
  kubeletExtraArgs:
    cloud-provider: aws
EOF

# Command to join the cluster
result = $(kubeadm join --config /home/ubuntu/worker-config.yaml)
echo "kubeadm join output ==> $${result}."

# Delete generated token
echo "deleting kubernetes token"
sh_command_id=$(aws ssm send-command \
    --instance-ids "$${instance}" \
    --document-name "AWS-RunShellScript" \
    --comment "Delete kubernetes token" \
    --parameters commands="kubeadm token delete $${token}" \
    --output text \
    --query "Command.CommandId" \
    --region ${region})
sleep 5
result=$(aws ssm list-command-invocations --command-id "$${sh_command_id}" --details --region ${region} | jq -j ".CommandInvocations[0].CommandPlugins[0].Output")
echo $${result}