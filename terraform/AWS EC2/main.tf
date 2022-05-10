terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider with IAM user and region.
provider "aws" {
  region     = "us-east-1"
  access_key = "<IAM SERVICE USER ACCESS KEY>"
  secret_key = "<IAM SERVICE USER SECRET KEY>"
}

# Create a VPC
resource "aws_vpc" "canary_vpc" {
  cidr_block = "10.0.0.0/16"
}
# Create Subnet
resource "aws_subnet" "canary_subnet" {
  vpc_id     = aws_vpc.canary_vpc.id
  cidr_block = "10.0.0.0/24"
}
# Create Bird NIC
resource "aws_network_interface" "canary_nic" {
  subnet_id   = aws_subnet.canary_subnet.id
  private_ips = ["10.0.0.5"]
}
# Create EC2 Instance AMI ID can be found in the "My AMI's" -> "Shared with me" AMI Catalog https://console.aws.amazon.com/ec2/v2/home#AMICatalog: NOTE: AMI's ARE REGION SPECIFIC
resource "aws_instance" "my_canary" {
  ami           = "ami-<AMI-ID>"
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.canary_nic.id
    device_index         = 0
  }
}