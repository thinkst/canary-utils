variable "tf_config" {
  type = object({
    aws_profile          = string
    aws_region           = string
    aws_account          = string
    aws_account_security = string
    environment          = string
  })
  description = "Current TF config"
}

variable "name" {
  description = "Name to be used on all resources as prefix"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "ID of the Canary AMI provided by Thinkst"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "The key name to use for the instance"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to launch the instance into"
  type        = string
}

variable "subnets" {
  description = "The VPC subnets to launch the instances into"
  type        = list(string)
}

variable "public_ip" {
  description = "If true, the EC2 instances will have associated public IP address"
  type        = bool
  default     = false
}

variable "size" {
  description = "Desired size of the ASG"
  type        = number
  default     = 1
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks allowed ingress into the ASG's instances"
  type        = list(string)
  default     = []
}

variable "allowed_egress_cidrs" {
  description = "List of CIDR blocks to which the egress from the ASG's instances is allowed"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
