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