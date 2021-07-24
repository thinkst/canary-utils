data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "main" {
  name   = "standalone-${var.name}"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = var.allowed_egress_cidrs
  }

  tags = {
    Env  = var.tf_config.environment
    Name = var.name
  }
}
