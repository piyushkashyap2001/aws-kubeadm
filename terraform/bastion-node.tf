resource "aws_security_group" "k8s_bastion_sg" {
  name_prefix = "k8s_bastion_sg_"
  description = "Communication with different nodes via ssh"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name      = "k8s_bastion_sg"
    CreatedBy = "terraform"
  }
}

resource "aws_security_group_rule" "bastion_allow_cidr" {
  cidr_blocks       = var.allowed_workstations_cidr
  description       = "Allow the cidr range to access ssh port"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_bastion_sg.id
  type              = "ingress"
}

resource "aws_security_group_rule" "bastion_connect_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the bastion host to connect to internet on port 80"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_bastion_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "bastion_connect_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow the bastion host to connect to internet on port 443"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_bastion_sg.id
  type              = "egress"
}

resource "aws_security_group_rule" "bastion_connect_ssh_across_vpc" {
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow the bastion host to ssh into any node within vpc"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_bastion_sg.id
  type              = "egress"
}

resource "aws_launch_configuration" "bastion_launch_conf" {
  associate_public_ip_address = true
  image_id                    = data.aws_ami.k8s_worker_ami.id
  instance_type               = "t2.micro"
  key_name                    = var.cluster["k8s_ssh_key_name"]
  name_prefix                 = "terraform-bastion-"
  security_groups             = ["${aws_security_group.k8s_bastion_sg.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion_asg" {
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.bastion_launch_conf.id
  max_size             = 1
  min_size             = 1
  name_prefix          = "terraform-bastion-asg-"
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "terraform-k8s-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "Accessibility"
    value               = "Public"
    propagate_at_launch = true
  }
}


