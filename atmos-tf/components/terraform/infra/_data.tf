data "aws_security_group" "ecs_sg" {
  name = "${var.namespace}_ecs_sg"
}
data "aws_security_group" "alb_sg" {
  name = "${var.namespace}_lb_sg"
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
sudo bash -c 'sudo echo ECS_CLUSTER=${aws_ecs_cluster.tnote_ecs_cluster.name} >> /etc/ecs/ecs.config'
sudo systemctl start docker
sudo systemctl start ecs
sudo systemctl enable docker
sudo systemctl enable ecs
EOF
}
data "aws_iam_role" "ecs_te_role" {
  name = "ecsTaskExecutionRole"
}