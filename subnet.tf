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