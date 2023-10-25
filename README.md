## Simple Terraform configuration
A Terraform configuration that provisions the following infrastructure:

A VPC with:

a. Public subnets for external resources.

b. Private subnets for internal resources.

EC2 instances:

a. Deployed within the private subnets.

b. Running a web server that displays the hostname of the instance which received the request.

Requirements:

Autoscaling:

a. Configure the EC2 instances to scale based on demand using AWS Auto Scaling Groups.

Expose the web application:

a. Make the web application reachable from the internet while keeping the EC2 instances in the private subnets.

 
***A VPC with:***
- a. Public subnets for external resources.
- b. Private subnets for internal resources.

***EC2 instances:***
- a. Deployed within the private subnets.
- b. Running a web server that displays the hostname of the instance which received the request.

### Requirements:
***Autoscaling:***
- a. Configure the EC2 instances to scale based on demand using AWS Auto Scaling Groups.

***Expose the web application:***
- a. Make the web application reachable from the internet while keeping the EC2 instances in the private subnets.

### Environment 
| SETUP | ENV |
| ------ | ------ |
| Provider | [AWS] |
| Region | [eu-west-1] [eu-west-1a] [eu-west-1b] |
| VPC cidr_block | [192.168.0.0/16] |
| Public-Subnet | [192.168.0.0/24] |
| Private-Subnet | [192.168.1.0/24] |
| Route NAT Gateway | [cidr_block = "0.0.0.0/0"] |
| Bastion ec2 | [t2.micro] |
| Nginx | [t2.micro] |
| docker image | [https://hub.docker.com/r/nginxdemos/hello/] |
| Security groups | [tcp/22 - http/80] |
| CertManager | [NO] |
| Route53 | [NO] |

### References
| Resource | URL |
| ------ | ------ |
| Terraform Autoscaling Module | https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest |
| Terraform Autoscaling Policy | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy |
| Terraform Fargate | https://registry.terraform.io/modules/almirosmanovic/fargate/aws/latest/examples/autoscaling |

### Procedure
If doesn't exist, we need an AWS profile using aws configure command, it will be used in terrform provider for authentication.

```sh
$ aws configure --profile garanet
```

> We need to modify the **provider.tf** file with the right values, so Terraform contacts the AWS API for the infrastructure provisioning.

```sh
# AWS provider
provider "aws" {
  profile = "garanet"
  region  = "eu-west-1"
}
```
> The **key.tf** file is for Private Key and Key pair. We will create a key_pair in AWS using aws_key_pair resource, this key will be used to ssh into instances.

```sh
# RSA 4096 bits
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Key pair with the above private key
resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.private_key.public_key_openssh
   depends_on = [tls_private_key.private_key]
}
# Private key stored at a specified path.
resource "local_file" "saveKey" {
  content = tls_private_key.private_key.private_key_pem
  filename = "${var.base_path}${var.key_name}.pem"  
}
```
> The **vpc.tf**  to create a VPC with a simple net 192.168.0.0/16 and instance tenancy as default with the dns hostname enabled.

```sh
# VPC cidr
resource "aws_vpc" "vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "garanet-vpc"
  }
  enable_dns_hostnames = true
}
```
> The **subnet.tf** file to define the Public and Private. These subnets are inside the vpc created before:

- The first subnet is the public-subnet with cidr block 192.168.0.0/24 in region eu-west-1 and eu-west-1a, enabling map_public_ip_on_launch to force the instance in this subnet with a public ip.
- The second subnet is the private subnet with cidr block 192.168.1.0/24 in region eu-west-1 and eu-west-1b, without the map_public_ip_on_launch, due it's a private subnet.
```sh
# Public subnet
resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.vpc,
  ]
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone_id = "gaga1-az1"
  tags = {
    Name = "public-subnet"
  }
  map_public_ip_on_launch = true
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  depends_on = [
    aws_vpc.vpc,
  ]
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone_id = "gaga1-az3"
  tags = {
    Name = "private-subnet"
  }
}
```
> The **internet_gateway.tf** allows communication between the VPC and the internet.
It provides a target into the VPC route tables for the internet-routable traffic, and performs the network address translation (NAT) for instances that have been assigned public IPv4 addresses.

```sh
# Internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  depends_on = [
    aws_vpc.vpc,
  ]
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "internet-gateway"
  }
}
```

> The **ig_route.tf** is a route table with target as internet gateway and associate it to public subnet so instances inside public subnet have internet connectivity. It has a route table with cidr “0.0.0.0/0” means on any ip, with Internet gateway as target.

```sh
# Route table with internet gateway as target
resource "aws_route_table" "IG_route_table" {
  depends_on = [
    aws_vpc.vpc,
    aws_internet_gateway.internet_gateway,
  ]
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "IG-route-table"
  }
}
# Route table to the public subnet
resource "aws_route_table_association" "associate_routetable_to_public_subnet" {
  depends_on = [
    aws_subnet.public_subnet,
    aws_route_table.IG_route_table,
  ]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.IG_route_table.id
}
```

> The **eip_nat.tf** (Elastic IP) to associate the route table to the public subnet. 

```sh
# Elastic IP
resource "aws_eip" "elastic_ip" {
  vpc      = true
}
# NAT gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on = [
    aws_subnet.public_subnet,
    aws_eip.elastic_ip,
  ]
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "nat-gateway"
  }
}
```

> The **NAT_route.tf** is the NAT Route Table and Private-subnet association with target as NAT gateway and associates it to the private subnet, to permit the instances (in private subnets) to connect to the internet.
Private Subnets Requests --> NAT GW --> Internet

```sh
# Route table with target as NAT gateway
resource "aws_route_table" "NAT_route_table" {
  depends_on = [
    aws_vpc.vpc,
    aws_nat_gateway.nat_gateway,
  ]
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "NAT-route-table"
  }
}

# Associated route table to private subnet
resource "aws_route_table_association" "associate_routetable_to_private_subnet" {
  depends_on = [
    aws_subnet.private_subnet,
    aws_route_table.NAT_route_table,
  ]
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.NAT_route_table.id
}
```

> The **bastion_host.tf** (as best AWS practice) is a server to provide access to a private network from an external network. A bastion host must minimize the chances of penetration, avoiding its exposure to potential attack from internet.
SSH access can be done, via internal network (VPN/VPC), instead to expose it to internet.

```sh
# Bastion Security Groups
resource "aws_security_group" "sg_bastion_host" {
  depends_on = [
    aws_vpc.vpc,
  ]
  name        = "sg bastion host"
  description = "bastion host security groups"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion host ec2 instance
resource "aws_instance" "bastion_host" {
  depends_on = [
    aws_security_group.sg_bastion_host,
  ]
  ami = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.sg_bastion_host.id]
  subnet_id = aws_subnet.public_subnet.id
  tags = {
      Name = "bastion host"
  }

  provisioner "file" {
    source      = "/home/garanet/terraform/ec2Key.pem"
    destination = "/home/ec2-user/ec2Key.pem"
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.private_key.private_key_pem
    host     = aws_instance.bastion_host.public_ip
    }
  }
}
```
> Finally the **nginx_demo.tf**, the webserver.

```sh
# nginxdemo security groups
resource "aws_security_group" "sg_nginxdemo" {
  depends_on = [
    aws_vpc.vpc,
  ]

  name        = "sg nginxdemo"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "allow TCP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_bastion_host.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# nginxdemo ec2 instance
resource "aws_instance" "nginxdemo" {
  depends_on = [
    aws_security_group.sg_nginxdemo    
  ]
  ami = "ami-xxxxxxxxxxxxxxxxx"              
  instance_type = "t2.micro"
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.sg_nginxdemo.id]
  subnet_id = aws_subnet.public_subnet.id
  user_data = <<EOF
            #! /bin/bash
            yum update
            yum install docker -y
            systemctl restart docker
            systemctl enable docker
            docker pull nginxdemos/hello
            docker run --name nginxdemo -p 80:80 -d nginxdemo
  EOF

  tags = {
      Name = "nginxdemo"
  }
}
```

### Deploy the infrastructure
> We can apply the terraform templates to make all infrastructure with:

```sh
$ terraform init
$ terraform plan
$ terraform apply
```

### Fargate Autoscaling Example
```sh
terraform {
  required_version = "~> 0.11.11"
}

provider "aws" {
  version = "~> 1.54.0"
  region  = "eu-west-1"
  profile = "playground"
}

module "fargate" {
  source = "../../"

  name = "autoscaling-nginxdemo"

  services = {
    api = {
      task_definition = "../basic/api.json"
      container_port  = 80
      cpu             = "256"
      memory          = "512"
      replicas        = 3

      auto_scaling_max_replicas     = 5  // Will scale out up to 5 replicas
      auto_scaling_max_cpu_util = 60 // If Avg CPU Utilization reaches 60%, scale up operations gets triggered
    }
  }
}
```

```sh
# VPC
output "vpc" {
  value = "${module.fargate.vpc}"
}

# ECR
output "ecr" {
  value = "${module.fargate.ecr_repository}"
}

# ECS Cluster
output "ecs_cluster" {
  value = "${module.fargate.ecs_cluster}"
}

# ALBs
output "application_load_balancers" {
  value = "${module.fargate.application_load_balancers}"
}

# Security Groups
output "web_security_group" {
  value = "${module.fargate.web_security_group}"
}

output "services_security_groups" {
  value = "${module.fargate.services_security_groups}"
}

# CloudWatch
output "cloudwatch_log_groups" {
  value = "${module.fargate.cloudwatch_log_groups}"
}
```