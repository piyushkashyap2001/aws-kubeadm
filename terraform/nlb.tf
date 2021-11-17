resource "aws_lb" "k8snlb" {
  name_prefix        = "nlb-"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  tags = {
    Environment                                            = "${var.cluster["environment"]}"
    "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared",
    "Name"                                                 = "${var.cluster["cluster_name"]}_nlb",
    "createdBy"                                            = "terraform",
  }
}

resource "aws_lb_listener" "agents_6443" {
  load_balancer_arn = aws_lb.k8snlb.arn
  protocol          = "TCP"
  port              = 6443

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agents_6443.arn
  }
}

resource "aws_lb_target_group" "agents_6443" {
  port     = 6443
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  depends_on = [
    aws_lb.k8snlb
  ]
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
    protocol            = "TCP"
    port                = 6443
  }
}


