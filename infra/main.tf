terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------
# Provider
# ------------------------
provider "aws" {
  region = var.region
  # 필요시 프로필 지정:
  # profile = "terra-admin"
}

# ------------------------
# Networking (VPC/Public Subnets/IGW/Route)
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
# Security Group (HTTP/HTTPS/NPM Admin/SSH)
# ------------------------
resource "aws_security_group" "sg_1" {
  name   = "${var.prefix}-sg-1"
  vpc_id = aws_vpc.vpc_1.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx Proxy Manager admin (초기엔 전체, 운영 전 내 IP/32로 제한 권장)
  ingress {
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (초기엔 전체, 운영 전 내 IP/32로 제한 권장)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 전체 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.prefix}-sg-1" }
}

# ------------------------
# IAM (SSM & S3)
# ------------------------
resource "aws_iam_role" "ec2_role_1" {
  name               = "${var.prefix}-ec2-role-1"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

  tags = { Name = "${var.prefix}-ec2-role-1" }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "instance_profile_1" {
  name = "${var.prefix}-instance-profile-1"
  role = aws_iam_role.ec2_role_1.name
  tags = { Name = "${var.prefix}-instance-profile-1" }
}

# ------------------------
# User Data Script (Amazon Linux 2023 + dnf)
# ------------------------
locals {
  ec2_user_data_base = <<-END_OF_FILE
#!/bin/bash
set -eux

# ===== System prep =====
# swap 4GB
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# timezone
timedatectl set-timezone Asia/Seoul || true

# env
echo "PASSWORD_1=${var.password_1}"                            >> /etc/environment
echo "APP_1_DOMAIN=${var.app_1_domain}"                        >> /etc/environment
echo "APP_1_DB_NAME=${var.app_1_db_name}"                      >> /etc/environment
echo "GITHUB_ACCESS_TOKEN_1_OWNER=${var.github_access_token_1_owner}" >> /etc/environment
echo "GITHUB_ACCESS_TOKEN_1=${var.github_access_token_1}"              >> /etc/environment
source /etc/environment

# ===== Packages (AL2023 uses dnf) =====
dnf -y update
dnf -y install ca-certificates curl git

# Docker (AL2023 repo)
if ! command -v docker >/dev/null 2>&1; then
  dnf -y install docker
fi
systemctl enable docker
systemctl start docker

# (만약 위가 실패하면 아래 대안 사용)
# dnf -y install dnf-plugins-core
# dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# dnf -y install docker-ce docker-ce-cli containerd.io
# systemctl enable docker && systemctl start docker

# ===== Docker network =====
docker network create common || true

# ===== Nginx Proxy Manager =====
docker run -d --name npm_1 --restart unless-stopped --network common \
  -p 80:80 -p 443:443 -p 81:81 \
  -e TZ=Asia/Seoul \
  -e INITIAL_ADMIN_EMAIL=admin@npm.com \
  -e INITIAL_ADMIN_PASSWORD=${var.password_1} \
  -v /dockerProjects/npm_1/volumes/data:/data \
  -v /dockerProjects/npm_1/volumes/etc/letsencrypt:/etc/letsencrypt \
  jc21/nginx-proxy-manager:latest

# ===== Redis =====
docker run -d --name redis_1 --restart unless-stopped --network common \
  -p 6379:6379 -e TZ=Asia/Seoul \
  -v /dockerProjects/redis_1/volumes/data:/data \
  redis:7-alpine --requirepass ${var.password_1}

# ===== MySQL 8 =====
docker run -d --name mysql_1 --restart unless-stopped \
  -v /dockerProjects/mysql_1/volumes/var/lib/mysql:/var/lib/mysql \
  -v /dockerProjects/mysql_1/volumes/etc/mysql/conf.d:/etc/mysql/conf.d \
  --network common -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=${var.password_1} \
  -e TZ=Asia/Seoul \
  mysql:8

echo "Waiting for MySQL..."
until docker exec mysql_1 mysql -uroot -p${var.password_1} -e "SELECT 1" &>/dev/null; do
  sleep 5
done

docker exec mysql_1 mysql -uroot -p${var.password_1} -e "
CREATE USER 'lldjlocal'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '1234';
CREATE USER 'lldjlocal'@'172.18.%.%' IDENTIFIED WITH caching_sha2_password BY '1234';
CREATE USER 'lldj'@'%' IDENTIFIED WITH caching_sha2_password BY '${var.password_1}';
GRANT ALL PRIVILEGES ON *.* TO 'lldjlocal'@'127.0.0.1';
GRANT ALL PRIVILEGES ON *.* TO 'lldjlocal'@'172.18.%.%';
GRANT ALL PRIVILEGES ON *.* TO 'lldj'@'%';
CREATE DATABASE IF NOT EXISTS \`${var.app_1_db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
FLUSH PRIVILEGES;
"

# GHCR login (read:packages)
echo "${var.github_access_token_1}" | docker login ghcr.io -u ${var.github_access_token_1_owner} --password-stdin || true
END_OF_FILE
}

# ------------------------
# AMI (Amazon Linux 2023 x86_64)
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
# EC2 + Elastic IP
# ------------------------
resource "aws_instance" "ec2_1" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.sg_1.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.instance_profile_1.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  tags = { Name = "${var.prefix}-ec2-1" }

  user_data = <<-EOF
${local.ec2_user_data_base}
EOF
}

resource "aws_eip" "eip_1" {
  domain   = "vpc"
  instance = aws_instance.ec2_1.id
  tags     = { Name = "${var.prefix}-eip-1" }
}
