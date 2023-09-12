provider "aws" {
  region     = "ap-southeast-1"
  access_key = "AKIAS4RV3HC7YQ7FIBXD"
  secret_key = "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"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "Terraform-vpc"
  cidr = "10.0.0.0/24"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.0.128/28", "10.0.0.144/28", "10.0.0.160/28"]
  public_subnets  = ["10.0.0.0/28", "10.0.0.16/28", "10.0.0.32/28"]

  create_igw         = true
  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "haizzz" {
  name        = "AllowHTTPAndSSH"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_launch_template" "haizzz" {
  name = "HaizzzLaunchTemplate"

  description = "Launch template created from terraform."

  image_id = "ami-0db1894e055420bc0"

  instance_type = "t2.micro"

  key_name = "HoangNgocNam-Keypair"

  network_interfaces {
    subnet_id                   = "subnet-0760c756503946471"
    security_groups             = [aws_security_group.haizzz.id]
    associate_public_ip_address = true
  }

  ebs_optimized = false

  user_data = filebase64("user-data.sh")

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_autoscaling_group" "haizzz" {
  name                      = "HaizzzAutoScalingGroup"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  desired_capacity          = 1
  health_check_type         = "ELB"
  vpc_zone_identifier       = module.vpc.public_subnets

  launch_template {
    id      = aws_launch_template.haizzz.id
    version = "$Latest"
  }
}

resource "aws_lb" "haizzz" {
  name               = "HaizzzLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.haizzz.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "haizzz" {
  name     = "HaizzzTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener" "haizzz" {
  load_balancer_arn = aws_lb.haizzz.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haizzz.arn
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_autoscaling_attachment" "haizzz" {
  autoscaling_group_name = aws_autoscaling_group.haizzz.id
  lb_target_group_arn    = aws_lb_target_group.haizzz.arn
}

resource "aws_autoscaling_policy" "haizzz" {
  autoscaling_group_name = aws_autoscaling_group.haizzz.name
  name                   = "HaizzzAutoScalingPolicy"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40.0
  }
}
