provider "aws" {
  access_key = "********************************"
  secret_key = "********************************"
  region     = "us-west-2"
}

# Create an EC2 instance and specify the security group
resource "aws_instance" "instance"{
      ami = var.ami_id       
      instance_type = var.instance_type
      vpc_security_group_ids = [aws_security_group.example.id]
      subnet_id = aws_subnet.example.id
      key_name = var.key_name

      user_data = <<-EOF
      #!/bin/bash
      echo "*** Installing apache2"
      sudo apt-get install apache2 -y
      sudo systemctl enable apache2
      sudo systemctl start apache2
      echo "*** Completed Installing apache2"
      EOF

}

output "my-public-ip"{
       value = aws_instance.instance.public_ip
}