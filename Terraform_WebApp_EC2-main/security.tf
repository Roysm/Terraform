# Create a security group that allows all inbound traffic
resource "aws_security_group" "example" {
  name        = "allow_all_inbound"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "Allow all inbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}