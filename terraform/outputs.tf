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


