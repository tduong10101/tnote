resource "aws_db_subnet_group" "db_sn" {
  name       = "tnote_db_sn"
  subnet_ids = data.aws_subnets.tnote_sn.ids

  tags = {
    Name = "tnote-db subnet"
  }
}

resource "aws_db_instance" "tnote_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  username               = "root"
  password               = var.db_pass
  port                   = 3306
  publicly_accessible    = true
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_sn.name
  vpc_security_group_ids = ["${data.aws_security_group.db_sg.id}"]
}

resource "aws_launch_template" "tnote_lt" {
  name_prefix   = "${var.namespace}_template"
  image_id      = "ami-07b5c2e394fccab6e"
  instance_type = "t3.micro"
  key_name      = "aws-ec2-kp"

  instance_initiated_shutdown_behavior = "terminate"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [data.aws_security_group.ecs_sg.id]
  }
  iam_instance_profile {
    name = "ecsInstanceRole"
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.namespace}_instance"
    }
  }

  user_data  = base64encode(data.template_file.ecs_user_data.rendered)
  depends_on = [aws_ecs_cluster.tnote_ecs_cluster]
}

resource "aws_autoscaling_group" "tnote_acg" {
  vpc_zone_identifier = data.aws_subnets.tnote_sn.ids
  max_size            = 1
  min_size            = 1

  launch_template {
    id      = resource.aws_launch_template.tnote_lt.id
    version = "$Latest"
  }
}

resource "aws_route53_record" "tnote_record" {
  zone_id = data.aws_route53_zone.tdinvoke.id
  name    = "tnote.tdinvoke.net"
  type    = "A"

  alias {
    name                   = aws_lb.tnote_alb.dns_name
    zone_id                = aws_lb.tnote_alb.zone_id
    evaluate_target_health = true
  }
}
resource "aws_lb" "tnote_alb" {
  name               = "${var.namespace}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${data.aws_security_group.alb_sg.id}"]
  subnets            = data.aws_subnets.tnote_sn.ids
  tags = {
    Name = "${var.namespace}_alb"
  }
}

resource "aws_lb_listener" "tnote_alb_listener" {
  load_balancer_arn = resource.aws_lb.tnote_alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.tnote_tg.arn
  }
}

resource "aws_lb_target_group" "tnote_tg" {
  name        = "${var.namespace}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.tnote_vpc.id

  health_check {
    path = "/"
  }
}
resource "aws_ecs_cluster" "tnote_ecs_cluster" {
  name = "${var.namespace}_ecs_cluster"
}

resource "aws_ecs_capacity_provider" "tnote_ecs_cp" {
  name = "${var.namespace}_ecs_cp"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.tnote_acg.arn

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 3
    }
  }
}
resource "aws_ecs_cluster_capacity_providers" "tnote_ecs_cluster_cp" {
  cluster_name = aws_ecs_cluster.tnote_ecs_cluster.name

  capacity_providers = [aws_ecs_capacity_provider.tnote_ecs_cp.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.tnote_ecs_cp.name
  }
}

resource "aws_ecs_task_definition" "tnote_td" {
  family                = "${var.namespace}_td"
  network_mode          = "awsvpc"
  execution_role_arn    = data.aws_iam_role.ecs_te_role.arn
  cpu                   = 1024
  container_definitions = <<DEFINITION
  [
    {
      "name"   : "tnote_docker",
      "image"  : "069363837566.dkr.ecr.ap-southeast-2.amazonaws.com/my-ecr-repo:tnote",
      "cpu"    : 1024,
      "memory" : 512,
      "environment" : [
        {
          "name"  : "SQL_USERNAME",
          "value" : "${aws_db_instance.tnote_db.username}"
        },
        {
          "name"  : "SQL_PASSWORD",
          "value" : "${var.db_pass}"
        },
        {
          "name"  : "SQL_HOST",
          "value" : "${aws_db_instance.tnote_db.address}"
        },
        {
          "name"  : "SQL_PORT",
          "value" : "${aws_db_instance.tnote_db.port}"
        },
        {
          "name"  : "DB_NAME",
          "value" : "tnotedb"
        }
      ],
      "portMappings" : [
        {
          "containerPort" : 80,
          "hostPort"      : 80
        }
      ],
      "logConfiguration": { 
        "logDriver": "awslogs",
        "options": { 
            "awslogs-group" : "/ecs/tnote-ecs-log",
            "awslogs-region": "${var.aws_region}",
            "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
}
resource "aws_cloudwatch_log_group" "tnote_ecs_lg" {
  name              = "/ecs/tnote-ecs-log"
  retention_in_days = 1
}
resource "aws_ecs_service" "tnote_ecs_service" {
  name            = "${var.namespace}_service"
  cluster         = aws_ecs_cluster.tnote_ecs_cluster.id
  task_definition = aws_ecs_task_definition.tnote_td.arn
  desired_count   = 1
  triggers = {
    redeployment = true
  }
  network_configuration {
    subnets         = data.aws_subnets.tnote_sn.ids
    security_groups = ["${data.aws_security_group.ecs_sg.id}"]
  }

  force_new_deployment = true
  placement_constraints {
    type = "distinctInstance"
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.tnote_ecs_cp.name
    weight            = 100
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.tnote_tg.arn
    container_name   = "tnote_docker"
    container_port   = 80
  }

  depends_on = [aws_autoscaling_group.tnote_acg]
}
