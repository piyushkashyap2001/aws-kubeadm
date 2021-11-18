data "template_file" "userdata" {
  template = file("worker-userdata.sh.tpl")

  vars = {
    tag_value = "terraform-${var.cluster["cluster_name"]}-masters-private"
    region    = var.region
  }
}

resource "aws_iam_role" "k8s_worker_nodes_role" {
  name_prefix = "k8s_worker_nodes_role_"

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


resource "aws_iam_role_policy_attachment" "AmazonSSMFullAccess-policy-attach-worker" {
  role       = aws_iam_role.k8s_worker_nodes_role.id
  policy_arn = data.aws_iam_policy.AmazonSSMFullAccess.arn
}

resource "aws_iam_role_policy" "k8s_worker_nodes_policy" {
  name_prefix = "k8s_worker_nodes_policy_"
  role        = aws_iam_role.k8s_worker_nodes_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "k8s_worker_nodes_profile" {
  name_prefix = "k8s_worker_nodes_profile_"
  role        = aws_iam_role.k8s_worker_nodes_role.name
}

resource "aws_security_group" "k8s_worker_nodes_sg" {
  name_prefix = "k8s_worker_nodes_sg_"
  description = "Security group for worker nodes in the cluster"
  vpc_id      = module.vpc.vpc_id
  tags = (tomap({
    "Name"                                                 = "k8s_worker_nodes_sg",
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "owned",
  }))
}


resource "aws_security_group_rule" "k8s_worker_nodes_cluster_ingress" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k8s_worker_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_master_nodes_sg.id
  to_port                  = 10250
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s_worker_nodes_self_ingress" {
  description              = "Allow worker Kubelets and pods to communicate with other worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.k8s_worker_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  to_port                  = 0
  type                     = "ingress"
}

# resource "aws_security_group_rule" "k8s_worker_nodes_master_ingress" {
#   description              = "Allow pods to receive communication from the cluster control plane"
#   from_port                = 0
#   protocol                 = "-1"
#   security_group_id        = aws_security_group.k8s_worker_nodes_sg.id
#   source_security_group_id = aws_security_group.k8s_master_nodes_sg.id
#   to_port                  = 0
#   type                     = "ingress"
# }

resource "aws_security_group_rule" "k8s_worker_nodes_ssh" {
  description              = "Allow bastion host to ssh into the worker nodes"
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k8s_worker_nodes_sg.id
  source_security_group_id = aws_security_group.k8s_bastion_sg.id
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "worker_connect_control_plane" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the worker node to communicate with api-server on port 6443"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "worker_connect_worker" {
  cidr_blocks       = [var.vpc_cidr] # Ideally it should be the security group id of worker_node but since terraform doesn't support destination as another security group so I added cidr range of VPC.
  description       = "Allow the worker node to communicate with other worker nodes on any protocol"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "worker_connect_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the worker node to connect to internet on port 80"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "worker_connect_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the worker node to connect to internet on port 443"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_worker_nodes_sg.id
  type              = "egress"
}

data "aws_ami" "k8s_worker_ami" {
  filter {
    name   = "name"
    values = [var.ami]
  }

  most_recent = true
  owners      = [var.aws_account_no]
}

resource "aws_launch_configuration" "k8s_worker_node_launch_conf" {
  iam_instance_profile        = aws_iam_instance_profile.k8s_worker_nodes_profile.name
  image_id                    = data.aws_ami.k8s_worker_ami.id
  instance_type               = var.cluster_worker["instance_type"]
  key_name                    = var.cluster["k8s_ssh_key_name"]
  name_prefix                 = "terraform-${var.cluster["cluster_name"]}-"
  associate_public_ip_address = false
  security_groups             = ["${aws_security_group.k8s_worker_nodes_sg.id}"]
  user_data = data.template_file.userdata.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "k8s_worker_node_asg" {
  enabled_metrics      = var.autoscaling_group_enabled_metrics
  launch_configuration = aws_launch_configuration.k8s_worker_node_launch_conf.id
  desired_capacity     = var.cluster_worker["desired_capacity"]
  max_size             = var.cluster_worker["max_size"]
  min_size             = var.cluster_worker["min_size"]
  name_prefix          = "terraform-${var.cluster["cluster_name"]}-worker-asg-"
  vpc_zone_identifier  = module.vpc.private_subnets

  tag {
    key                 = "Name"
    value               = "terraform-${var.cluster["cluster_name"]}-workers-private"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster["cluster_name"]}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster-autoscaler/${var.cluster["cluster_name"]}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster-autoscaler/enabled"
    value               = "TRUE"
    propagate_at_launch = true
  }
}
