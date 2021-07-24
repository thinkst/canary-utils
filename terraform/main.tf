terraform {
  backend "s3" {}
}

provider "aws" {
  profile             = var.tf_config.aws_profile
  region              = var.tf_config.aws_region
  allowed_account_ids = [var.tf_config.aws_account]
}

resource "aws_launch_template" "main" {
  name          = var.name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    security_groups             = [aws_security_group.main.id]
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Env  = var.tf_config.environment
      Name = var.name
    }
  }
}

resource "aws_autoscaling_group" "main" {
  name                = var.name
  desired_capacity    = var.size
  min_size            = var.size
  max_size            = var.size
  vpc_zone_identifier = var.subnets

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }
}
