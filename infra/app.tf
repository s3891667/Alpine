# I parse app1 and app2 instance into a global variable vms for easier deploy
locals {
  vms = {
    app1 = {
      ami             = data.aws_ami.ubuntu.id
      instance_type   = "t2.micro"
      subnet_id       = aws_subnet.public3.id
      key_name        = aws_key_pair.admin.key_name
      security_groups = [aws_security_group.vms_for_app.id]
      tags = {
        Name = "foo app1"
      }
    },

    app2 = {
      ami             = data.aws_ami.ubuntu.id
      instance_type   = "t2.micro"
      subnet_id       = aws_subnet.public2.id
      key_name        = aws_key_pair.admin.key_name
      security_groups = [aws_security_group.vms_for_app.id]
      tags = {
        Name = "foo app2"
      }
    },

  }
}

#Security for foo apps
resource "aws_security_group" "vms_for_app" {
  name   = "vms_for_app"
  vpc_id = aws_vpc.custom_vpc.id

  # SSH
  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP in
  ingress {
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL in
  egress {
    from_port   = 0
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS out
  egress {
    from_port   = 0
    to_port     = 443
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


#Indicate a virutal machine for EC2
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

#Generate private key method 
resource "tls_private_key" "owenDevOpskey" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

#Using the public key declared in var.path_to_ssh_public_key to generate private for aws key pair
resource "aws_key_pair" "admin" {
  key_name   = "owenDevOpskey"
  public_key = var.path_to_ssh_public_key
}


#Database Instance 
resource "aws_instance" "database" {
      ami             = data.aws_ami.ubuntu.id
      instance_type   = "t2.micro"
      key_name        = aws_key_pair.admin.key_name
      vpc_security_group_ids = [aws_security_group.vms_for_DB.id]
      tags = {
        Name = "foo db"
      }

}

#Loop the var to create 2 instances
resource "aws_instance" "servers" {
  for_each        = local.vms
  ami             = each.value.ami
  instance_type   = each.value.instance_type
  subnet_id       = each.value.subnet_id
  key_name        = each.value.key_name
  security_groups = each.value.security_groups
  tags            = each.value.tags
}



#Load balancer target group
resource "aws_lb_target_group" "foo_app" {
  name     = "foo-app-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id


}

#Load Balancer
resource "aws_lb" "foo_lb" {
  name               = "foolb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id]
  security_groups    = [aws_security_group.vms_for_app.id]
}

#Load Balancer listener
resource "aws_lb_listener" "foo_lb_listener" {
  load_balancer_arn = aws_lb.foo_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.foo_app.arn
  }
}



#This section declare route table association that show where subnets will attach 
#to which route table
resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_2_rt_a" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_3_rt_a" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_lb_target_group_attachment" "app1" {
  target_group_arn = aws_lb_target_group.foo_app.arn
  target_id        = aws_instance.servers["app1"].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app2" {
  target_group_arn = aws_lb_target_group.foo_app.arn
  target_id        = aws_instance.servers["app2"].id
  port             = 80
}

