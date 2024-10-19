provider "aws" {
    region  = "ap-southeast-2"
    profile = "opentofu"
}

# -----------------------------------------------------------------------------#
# VPC

resource "aws_vpc" "media_server" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "media-server-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "media_server_igw" {
    vpc_id = aws_vpc.media_server.id

    tags = {
        Name = "media-server-igw"
    }
}

# Public Subnet
resource "aws_subnet" "media_server_public_subnet" {
    vpc_id     = aws_vpc.media_server.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "media-server-public-subnet"
    }
}


# Route Table
resource "aws_route_table" "media_server_public_rt" {
    vpc_id = aws_vpc.media_server.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.media_server_igw.id
    }

    tags = {
        Name = "media-server-public-rt"
    }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "media_server_public_rt_assoc" {
    subnet_id      = aws_subnet.media_server_public_subnet.id
    route_table_id = aws_route_table.media_server_public_rt.id
}

# -----------------------------------------------------------------------------#
# Security Groups

resource "aws_security_group" "media_server_sg" {
    vpc_id = aws_vpc.media_server.id
    name        = "media-server-sg"
    description = "Allow SSH, ICMP, HTTP, HTTPS traffic"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = -1
        to_port     = -1
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 8096
        to_port     = 8096
        protocol    = "tcp"
        cidr_blocks = ["45.248.79.184/32"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
   }

    tags = {
        Name = "media-server-sg"
    }
}

# Security Group for EFS
resource "aws_security_group" "efs_sg" {
    vpc_id = aws_vpc.media_server.id
    name        = "efs-sg"
    description = "Security group for EFS"

    ingress {
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "efs-sg"
    }
}

# -----------------------------------------------------------------------------#
# EFS File System

resource "aws_efs_file_system" "efs" {
    creation_token = "media-server-efs"

    tags = {
        Name = "media-server-efs"
    }
}

# EFS Mount Target
resource "aws_efs_mount_target" "efs_mount" {
    file_system_id  = aws_efs_file_system.efs.id
    subnet_id       = aws_subnet.media_server_public_subnet.id
    security_groups = [aws_security_group.efs_sg.id]
}

# -----------------------------------------------------------------------------#
# EC2 

resource "aws_instance" "media_server" {
    ami           = "ami-001f2488b35ca8aad"
    instance_type = "t2.micro"
    key_name      = "media-server"
    vpc_security_group_ids = [aws_security_group.media_server_sg.id]
    
    subnet_id = aws_subnet.media_server_public_subnet.id
    associate_public_ip_address = true

    user_data = <<-EOF
        #!/bin/bash
        # Update the package repository
        sudo apt-get update -y

        # Install Docker
        sudo apt-get install -y docker.io

        # Start Docker service
        sudo systemctl start docker
        sudo systemctl enable docker

        # Install EFS mount helper
        sudo apt-get install -y amazon-efs-utils

        # Create a directory for EFS mount
        sudo mkdir -p /mnt/efs

        # Mount the EFS file system
        sudo mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /mnt/efs

        # Pull the Jellyfin Docker image
        sudo docker pull jellyfin/jellyfin

        # Run the Jellyfin container with EFS volume
        sudo docker run -d --name jellyfin -p 8096:8096 -v /mnt/efs:/config jellyfin/jellyfin
    EOF

    tags = {
        Name = "media-server"
    }
}

output "instance_public_ip" {
    value = aws_instance.media_server.public_ip
}

