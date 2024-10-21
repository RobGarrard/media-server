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
# Route53

resource "aws_route53_zone" "main" {
  name = "robort.site" 
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "A"
  ttl     = "300"
  records = [aws_instance.media_server.public_ip]
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
        cidr_blocks = ["0.0.0.0/0"]
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

# -----------------------------------------------------------------------------#
# EC2 

resource "aws_instance" "media_server" {
    ami           = "ami-001f2488b35ca8aad"
    instance_type = "t2.small"
    key_name      = "media-server"
    vpc_security_group_ids = [aws_security_group.media_server_sg.id]
    
    subnet_id = aws_subnet.media_server_public_subnet.id
    
    root_block_device {
        volume_size = 8
        volume_type = "gp3"
    }


    user_data = file("${path.module}/scripts/media_server_startup.sh")

    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

    
    tags = {
        Name = "media-server"
    }
}

output "instance_public_ip" {
    value = aws_instance.media_server.public_ip
}

# -----------------------------------------------------------------------------#
# S3 Bucket

resource "aws_s3_bucket" "robs_media_server" {
  bucket = "robs-media-server"

  tags = {
    Name = "robs-media-server"
  }
}

#-----------------------------------------------------------------------------#
# IAM

# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy
resource "aws_iam_policy" "s3_policy" {
  name        = "s3_policy"
  description = "Policy to allow EC2 instance to interact with S3"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::robs-media-server",
          "arn:aws:s3:::robs-media-server/*"
        ]
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}