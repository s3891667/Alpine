#AWS virutal private cloud
resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "foo app vpc"
  }
}

#Internet gatewat 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "my-igw"
  }
}


#Route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}




resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.4.0/22"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public AZ1"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.8.0/22"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Public AZ2"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public3" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.16.0/22"
  availability_zone = "us-east-1c"
  tags = {
    Name = "Public AZ3"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.20.0/22"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Private AZ1"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.24.0/22"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Private AZ2"
  }
  map_public_ip_on_launch = true
}



resource "aws_subnet" "private3" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.28.0/22"
  availability_zone = "us-east-1c"
  tags = {
    Name = "Private AZ3"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "data1" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.32.0/22"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Data AZ1"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "data2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.36.0/22"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Data AZ2"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "data3" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.40.0/22"
  availability_zone = "us-east-1c"
  tags = {
    Name = "Data AZ3"
  }
  map_public_ip_on_launch = true
}
