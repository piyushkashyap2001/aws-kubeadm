region              = "us-east-1"
vpc_cidr            = "192.168.0.0/16"
vpc_azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_public_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
vpc_private_subnets = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

cluster = {
  cluster_name     = "k8s-cluster"
  k8s_ssh_key_name = "k8s-key-pair"
  environment      = "dev"
}

ami = "<ami id>"

aws_account_no = "<aws account no>"

cluster_worker = {
  instance_type    = "t2.medium"
  max_size         = 5
  min_size         = 1
  desired_capacity = 1
}

cluster_master = {
  instance_type    = "t2.medium"
  max_size         = 5
  min_size         = 2
  desired_capacity = 2
}

autoscaling_group_enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

allowed_workstations_cidr = ["117.253.22.128"]

elb_region_owner_id = "127311923021"
