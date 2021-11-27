variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones"
  type        = list(any)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_public_subnets" {
  description = "Availability zones"
  type        = list(any)
  default     = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
}

variable "vpc_private_subnets" {
  description = "Availability zones"
  type        = list(any)
  default     = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
}


variable "cluster" {
  type = map(string)

  default = {
    cluster_name     = "k8s-cluster" # Name for the cluster.
    k8s_ssh_key_name = "k8s-key-pair"
    environment      = "dev"
  }
}

variable "ami" {
  type    = string
  default = ""
}

variable "cluster_worker" {
  type = map(string)

  default = {
    instance_type    = "t2.medium"
    max_size         = 5
    min_size         = 1
    desired_capacity = 1
  }
}

variable "cluster_master" {
  type = map(string)

  default = {
    instance_type    = "t2.medium"
    max_size         = 5
    min_size         = 2
    desired_capacity = 2
  }
}

variable "autoscaling_group_enabled_metrics" {
  default = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
}

variable "allowed_workstations_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "aws_account_no" {
  type    = string
  default = ""
}
