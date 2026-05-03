# # ============================================================


terraform {
  required_providers {
      aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  backend "s3" {
    bucket = "statefiledataroutefilesecet"
    key    = "statefiledataroutefilesecet/terraform.tfstate"
    region = "us-east-1"
  }
}

# ============================================================
# create vpc, subnet, and internet gateway
# ============================================================



provider "aws" {
  region = "us-east-1"
}


#============================================================
# Create Networking VPC
#============================================================
resource "aws_vpc" "route_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name    = "Route-vpc"
    
  }

  
}

#============================================================
# Create  Internet Gateway
#============================================================

resource "aws_internet_gateway" "route_igw" {
  vpc_id = aws_vpc.route_vpc.id
  tags = {
    Name    = "Route-igw"
  
  }
}

#============================================================
# create public subnet
#============================================================
resource "aws_subnet" "route_public_subnet1" {
  vpc_id     = aws_vpc.route_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true
  tags = {
    Name    = "Route-public-subnet_10.0.1.0"
    
  }

}

#============================================================
# create public subnet-2
#============================================================
resource "aws_subnet" "route_public_subnet2" {
  vpc_id     = aws_vpc.route_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[3]
  map_public_ip_on_launch = true
  tags = {
    Name    = "Route-public-subnet_10.0.2.0"
    
  }

}

# ============================================================
# Create Route Table and Route
# ============================================================
resource "aws_route_table" "route_public_rt" {
  vpc_id = aws_vpc.route_vpc.id
  
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.route_igw.id
  }


  tags = {
    Name    = "Route-public-rt"
    
  }
}

# ============================================================
# Associate Route Table with Subnet
# ============================================================

resource "aws_route_table_association" "route_public_rt_assoc1" {
  subnet_id      = aws_subnet.route_public_subnet1.id
  route_table_id = aws_route_table.route_public_rt.id
}

resource "aws_route_table_association" "route_public_rt_assoc2" {
  subnet_id      = aws_subnet.route_public_subnet2.id
  route_table_id = aws_route_table.route_public_rt.id
}


## ============================================================
# create Private subnet
# ============================================================

resource "aws_subnet" "route_Private_subnet3" {
  vpc_id     = aws_vpc.route_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]
  tags = {
    Name    = "Route-private-subnet_10.0.3.0"
    
  }

}

## ============================================================
# create Private subnet
# ============================================================

resource "aws_subnet" "route_Private_subnet4" {
  vpc_id     = aws_vpc.route_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[3]
  tags = {
    Name    = "Route-private-subnet_10.0.4.0"
    
  }

}


## ============================================================
# create NAT Gateway and Elastic IP
# ============================================================

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name    = "Route-nat-eip"
   
  }
  
}

resource "aws_nat_gateway" "route_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.route_public_subnet1.id
  tags = {
    Name    = "Route-nat-gw"
    
  }
  
}


## ============================================================
# create Private Route Table and Route

resource "aws_route_table" "route_private_rt" {
  vpc_id = aws_vpc.route_vpc.id
  
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.route_nat_gw.id
}
}



resource "aws_route_table_association" "route_public_rt_assoc3" {
  subnet_id      = aws_subnet.route_Private_subnet3.id
  route_table_id = aws_route_table.route_private_rt.id
}

resource "aws_route_table_association" "route_public_rt_assoc4" {
  subnet_id      = aws_subnet.route_Private_subnet4.id
  route_table_id = aws_route_table.route_private_rt.id
}




resource "aws_security_group" "ec2_sg" {
  name        = "terraform-sample-ec2-sg"
  vpc_id      = aws_vpc.route_vpc.id
  description = "Allow SSH and HTTP inbound traffic"

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  # HTTP access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

resource "aws_key_pair" "routekey" {
  key_name   = "routekey"
  public_key = file("${path.module}/id_rsa.pub")
}



resource "aws_instance" "route" {
  ami           = var.ami
  subnet_id = aws_subnet.route_public_subnet1.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.ec2_sg.id ]
  user_data_base64 = filebase64("${path.module}/user_data.sh")
  key_name = aws_key_pair.routekey.key_name
  tags = {
    Name = var.instance_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}



