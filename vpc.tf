# VPC cidr
resource "aws_vpc" "vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "garanet-vpc"
  }
  enable_dns_hostnames = true
}