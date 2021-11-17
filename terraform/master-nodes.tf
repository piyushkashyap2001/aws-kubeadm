locals {
  master_nodes_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
sudo hostnamectl set-hostname \
$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
USERDATA
}
resource "aws_iam_role" "k8s_master_nodes_role" {
  name_prefix = "k8s_master_nodes_role_"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "aws_iam_policy" "AmazonSSMFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMFullAccess-policy-attach-master" {
  role       = aws_iam_role.k8s_master_nodes_role.id
  policy_arn = data.aws_iam_policy.AmazonSSMFullAccess.arn
}

resource "aws_iam_role_policy" "k8s_master_nodes_policy" {
  name_prefix = "k8s_master_nodes_policy_"
  role        = aws_iam_role.k8s_master_nodes_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerPolicies",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "k8s_master_nodes_profile" {
  name_prefix = "k8s_master_nodes_profile_"
  role        = aws_iam_role.k8s_master_nodes_role.name
}

resource "aws_security_group" "k8s_master_nodes_sg" {
  name_prefix = "k8s_master_nodes_sg_"
  description = "Security group for master nodes in the cluster"
  vpc_id      = module.vpc.vpc_id



  tags = (tomap({
    "Name"                                                 = "k8s_master_nodes_sg",
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "owned",
  }))
}



resource "aws_security_group_rule" "k8s_master_nodes_etcd_ingress" {
  description              = "Allow master node etcd communication"
  from_port                = 2379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k8s_master_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_master_nodes_sg.id
  to_port                  = 2380
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s_master_nodes_components_ingress" {
  description              = "Allow master node kubernetes components communication"
  from_port                = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k8s_master_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_master_nodes_sg.id
  to_port                  = 10252
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s_master_nodes_lb_ingress" {
  description       = "Allow load balancer to connect to api-server"
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_master_nodes_sg.id
  cidr_blocks = ["0.0.0.0/0"]
  to_port     = 6443
  type        = "ingress"
}

resource "aws_security_group_rule" "k8s_master_nodes_ssh" {
  description              = "Allow bastion host to ssh into the master nodes"
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k8s_master_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_bastion_sg.id
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s_master_nodes_worker_ingress" {
  description              = "Allow master node to communicate with worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.k8s_master_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  to_port                  = 0
  type                     = "ingress"
}


resource "aws_security_group_rule" "master_connect_worker_kubelet" {
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow the master node to connect to worker node kubelets"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_master_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "master_connect_lb" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the master node to connect to load balancer"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_master_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "master_connect_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the master node to connect to internet on port 80"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_master_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "master_connect_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the master node to connect to internet on port 443"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_master_nodes_sg.id
  type              = "egress"
}

resource "aws_launch_configuration" "k8s_master_node_launch_conf" {
  iam_instance_profile        = aws_iam_instance_profile.k8s_master_nodes_profile.name
  image_id                    = data.aws_ami.k8s_worker_ami.id
  instance_type               = var.cluster_master["instance_type"]
  key_name                    = var.cluster["k8s_ssh_key_name"]
  name_prefix                 = "terraform-${var.cluster["cluster_name"]}-"
  associate_public_ip_address = false
  security_groups             = ["${aws_security_group.k8s_master_nodes_sg.id}"]
  user_data_base64            = base64encode(local.master_nodes_userdata)

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_autoscaling_group" "k8s_master_node_asg" {
  enabled_metrics      = var.autoscaling_group_enabled_metrics
  launch_configuration = aws_launch_configuration.k8s_master_node_launch_conf.id
  desired_capacity     = var.cluster_master["desired_capacity"]
  max_size             = var.cluster_master["max_size"]
  min_size             = var.cluster_master["min_size"]
  name_prefix          = "terraform-${var.cluster["cluster_name"]}-master-asg-"
  vpc_zone_identifier  = module.vpc.private_subnets

  tag {
    key                 = "Name"
    value               = "terraform-${var.cluster["cluster_name"]}-masters-private"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster["cluster_name"]}"
    value               = "owned"
    propagate_at_launch = true
  }
}


resource "aws_autoscaling_attachment" "asg_elb" {
  autoscaling_group_name = aws_autoscaling_group.k8s_master_node_asg.id  
  alb_target_group_arn = aws_lb_target_group.agents_6443.arn
}

