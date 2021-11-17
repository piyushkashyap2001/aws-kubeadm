module "vpc" {
  source                       = "terraform-aws-modules/vpc/aws"
  cidr                         = var.vpc_cidr
  azs                          = var.vpc_azs
  private_subnets              = var.vpc_private_subnets
  public_subnets               = var.vpc_public_subnets
  create_database_subnet_group = false
  enable_dns_hostnames         = true
  enable_dns_support           = true
  enable_nat_gateway           = true

  # vpc tags that will be applied to vpc
  tags = (tomap({
    "Name"      = "${var.cluster["cluster_name"]}_terraform_vpc_resource",
    "createdBy" = "terraform",
  }))

  vpc_tags = (tomap({
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared",
    "Name"                                                 = "${var.cluster["cluster_name"]}_vpc",
    "environment"                                          = "${var.cluster["environment"]}",
    "createdBy"                                            = "terraform",
  }))

  # Tag the subnets properly

  private_subnet_tags = (tomap({
    "Name"                                                 = "${var.cluster["cluster_name"]}_private_subnet",
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared",
    "kubernetes.io/role/internal-elb"                      = "1",
  }))
  public_subnet_tags = (tomap({
    "Name"                                                 = "${var.cluster["cluster_name"]}_public_subnet",
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared",
    "kubernetes.io/role/elb"                               = "1",
  }))
}

resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name = "k8s-${terraform.workspace}-vpc_log_group"
}

resource "aws_iam_role" "log_group_iam_role" {
  name_prefix = "k8s-${terraform.workspace}-log-group-role-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "vpc_log_group_policy" {
  name_prefix = "k8s-${terraform.workspace}-log-group-policy-"
  role        = aws_iam_role.log_group_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_flow_log" "vpc_flow_log" {
  log_destination = aws_cloudwatch_log_group.vpc_log_group.arn
  iam_role_arn    = aws_iam_role.log_group_iam_role.arn
  vpc_id          = module.vpc.vpc_id
  traffic_type    = "ALL"
}
