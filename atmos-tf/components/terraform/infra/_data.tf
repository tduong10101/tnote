data "aws_security_group" "ecs_sg" {
  name = "${var.namespace}_ecs_sg"
}
data "aws_security_group" "alb_sg" {
  name = "${var.namespace}_lb_sg"
}
data "aws_security_group" "db_sg" {
  name = "${var.namespace}_db_sg"
}
data "aws_vpc" "tnote_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.namespace]
  }
}
data "aws_subnets" "tnote_sn" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.tnote_vpc.id]

  }
}
data "template_file" "ecs_user_data" {
  template = <<EOF
#!/bin/bash
sudo yum install -y ecs-init
sudo echo ECS_CLUSTER="${aws_ecs_cluster.tnote_ecs_cluster.name}" | sudo tee /etc/ecs/ecs.config
sudo systemctl start docker
sudo systemctl enable --now --no-block ecs.service
EOF
}
data "aws_iam_role" "ecs_te_role" {
  name = "ecsTaskExecutionRole"
}
data "aws_route53_zone" "tdinvoke" {
  name = var.r53_zone_name
}
data "aws_acm_certificate" "cert" {
  domain = var.acm_cert_domain
}
