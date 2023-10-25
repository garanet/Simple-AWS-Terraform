# nginxdemo security group
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