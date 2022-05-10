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
  description = "Name of the Canary EC2 instance"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "ID of the Canary AMI provided by Thinkst"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to start. You shouldn't need anything more than t2.micro"
  type        = string
  default     = "t2.medium"
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
  description = "The VPC subnets to launch the instance(s) into"
  type        = list(string)
}

variable "public_ip" {
  description = "Set value to true if deploying an outside bird"
  type        = bool
  default     = false
}

variable "size" {
  description = "Desired size of the ASG used to manage the Canary EC2 instance(s)"
  type        = number
  default     = 1
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks allowed ingress into the ASG's Canary EC2 instances. The default value for outside bird should be ["0.0.0.0/0"]. The recommended value for inside birds is the VPC CIDR block"
  type        = list(string)
  default     = []
}

variable "allowed_egress_cidrs" {
  description = "List of CIDR blocks to which the egress from the ASG's Canary EC2 instances is allowed. You can lock this down by only allowing encrypted DNS on port 53 outbound to your local VPC resolver and 443 outbound to the Internet for DoH to Cloudflare"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
