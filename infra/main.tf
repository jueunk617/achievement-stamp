terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ------------------------
# Provider
# ------------------------
provider "aws" {
  region = var.region
}

# ------------------------
# Networking (VPC / Subnets / IGW / Route)
# ------------------------
resource "aws_vpc" "vpc_1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.prefix}-vpc-1" }
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.prefix}-subnet-1" }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = { Name = "${var.prefix}-subnet-2" }
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
  tags = { Name = "${var.prefix}-subnet-3" }
}

resource "aws_subnet" "subnet_4" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}d"
  map_public_ip_on_launch = true
  tags = { Name = "${var.prefix}-subnet-4" }
}

resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags   = { Name = "${var.prefix}-igw-1" }
}

resource "aws_route_table" "rt_1" {
  vpc_id = aws_vpc.vpc_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }

  tags = { Name = "${var.prefix}-rt-1" }
}

resource "aws_route_table_association" "association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt_1.id
}
resource "aws_route_table_association" "association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt_1.id
}
resource "aws_route_table_association" "association_3" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.rt_1.id
}
resource "aws_route_table_association" "association_4" {
  subnet_id      = aws_subnet.subnet_4.id
  route_table_id = aws_route_table.rt_1.id
}

# ------------------------
# Security Group 
# ------------------------
resource "aws_security_group" "sg_1" {
  name  = "${var.prefix}-sg-1"
  vpc_id = aws_vpc.vpc_1.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # all
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # all
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.prefix}-sg-1" }
}

# ------------------------
# IAM
# ------------------------
resource "aws_iam_role" "ec2_role_1" {
  name = "${var.prefix}-ec2-role-1"

  assume_role_policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Action":"sts:AssumeRole",
      "Principal":{ "Service":"ec2.amazonaws.com" },
      "Effect":"Allow"
    }
  ]
}
EOF

  tags = { Name = "${var.prefix}-ec2-role-1" }
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 강사님 코드 대비 최신/권장: SSM 접속은 이 정책 사용
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance_profile_1" {
  name = "${var.prefix}-instance-profile-1"
  role = aws_iam_role.ec2_role_1.name
  tags = { Name = "${var.prefix}-instance-profile-1" }
}

# ------------------------
# AMI (Amazon Linux 2023)
# ------------------------
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ------------------------
# EC2 
# ------------------------
locals {
  ec2_user_data_base = <<-END_OF_FILE
    #!/bin/bash
    set -euxo pipefail

    # 스왑 4GB
    dd if=/dev/zero of=/swapfile bs=128M count=32
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

    # 타임존
    timedatectl set-timezone Asia/Seoul || true

    # 환경변수 (Secrets 그대로 주입)
    echo "PASSWORD_1=${var.password_1}" >> /etc/environment
    echo "APP_DOMAIN=${var.app_domain}" >> /etc/environment
    echo "APP_DB_NAME=${var.app_1_db_name}" >> /etc/environment
    echo "GITHUB_ACCESS_TOKEN_1_OWNER=${var.github_access_token_1_owner}" >> /etc/environment
    echo "GITHUB_ACCESS_TOKEN_1=${var.github_access_token_1}" >> /etc/environment
    source /etc/environment

    # 도커 설치/기동
    dnf install -y docker
    systemctl enable docker
    systemctl start docker

    # 공용 도커 네트워크
    docker network create common || true

    # Nginx Proxy Manager
    docker run -d \
      --name npm_1 \
      --restart unless-stopped \
      --network common \
      -p 80:80 -p 443:443 -p 81:81 \
      -e TZ=Asia/Seoul \
      -e INITIAL_ADMIN_EMAIL=admin@npm.com \
      -e INITIAL_ADMIN_PASSWORD=${var.password_1} \
      -v /dockerProjects/npm_1/volumes/data:/data \
      -v /dockerProjects/npm_1/volumes/etc/letsencrypt:/etc/letsencrypt \
      jc21/nginx-proxy-manager:latest

    # Redis
    docker run -d \
      --name=redis_1 \
      --restart unless-stopped \
      --network common \
      -p 6379:6379 \
      -e TZ=Asia/Seoul \
      -v /dockerProjects/redis_1/volumes/data:/data \
      redis --requirepass ${var.password_1}

    # MySQL
    docker run -d \
      --name mysql_1 \
      --restart unless-stopped \
      --network common \
      -p 3306:3306 \
      -e MYSQL_ROOT_PASSWORD=${var.password_1} \
      -e TZ=Asia/Seoul \
      -v /dockerProjects/mysql_1/volumes/var/lib/mysql:/var/lib/mysql \
      -v /dockerProjects/mysql_1/volumes/etc/mysql/conf.d:/etc/mysql/conf.d \
      mysql:latest

    echo "MySQL 기동 대기..."
    until docker exec mysql_1 mysql -uroot -p${var.password_1} -e "SELECT 1" &>/dev/null; do
      echo "대기 5초..."
      sleep 5
    done

    docker exec mysql_1 mysql -uroot -p${var.password_1} -e "
      CREATE USER 'lldjlocal'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '1234';
      CREATE USER 'lldjlocal'@'172.18.%.%' IDENTIFIED WITH caching_sha2_password BY '1234';
      CREATE USER 'lldj'@'%' IDENTIFIED WITH caching_sha2_password BY '${var.password_1}';

      GRANT ALL PRIVILEGES ON *.* TO 'lldjlocal'@'127.0.0.1';
      GRANT ALL PRIVILEGES ON *.* TO 'lldjlocal'@'172.18.%.%';
      GRANT ALL PRIVILEGES ON *.* TO 'lldj'@'%';

      CREATE DATABASE \`${var.app_1_db_name}\`;
      FLUSH PRIVILEGES;
    "

    # GHCR 로그인 
    echo "${var.github_access_token_1}" | docker login ghcr.io -u ${var.github_access_token_1_owner} --password-stdin || true
  END_OF_FILE
}

resource "aws_instance" "ec2_1" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_2.id
  vpc_security_group_ids = [aws_security_group.sg_1.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.instance_profile_1.name

  tags = {
    Name = "terra-ec2-1"                # CI/CD에서 Name 태그로 찾을 수 있게 고정
    Project = var.prefix
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = <<-EOF
${local.ec2_user_data_base}
EOF
}
