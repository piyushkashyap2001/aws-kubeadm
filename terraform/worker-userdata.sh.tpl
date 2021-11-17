#!/bin/bash
set -o xtrace
sudo hostnamectl set-hostname \
$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
instances=$(aws ec2 describe-instances --filters "Name=tag-value,Values=${tag_value}" --region ${region}  | jq -r ".Reservations[].Instances[].InstanceId")
echo "control plane instances- $${instances}"
instance=$(echo $${instances}| cut -d ' ' -f 1)
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
join_command=$(echo $${result})
echo "executing join command"
$${join_command}
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