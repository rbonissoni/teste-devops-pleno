data "aws_ami" "debian12" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

data "aws_subnet" "sel" {
  id = var.subnet_id
}

resource "aws_security_group" "app_sg" {
  name        = "${var.name}-sg"
  description = "Allow SSH, HTTP, Jenkins"
  vpc_id      = data.aws_subnet.sel.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_instance" "app" {
  ami                         = data.aws_ami.debian12.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  # IMPORTANTE: recria a instância quando o user_data mudar
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh", {
    ENABLE_JENKINS = var.enable_jenkins
    REPO_URL       = var.repo_url
    REPO_BRANCH    = var.repo_branch
    DD_API_KEY     = var.dd_api_key
    DD_SITE        = var.dd_site
    DD_APP_KEY     = var.dd_app_key
    APP_ROOT       = "/var/www/app"
  })

  # (opcional, boa prática)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  tags = {
    Name = "${var.name}-ec2"
  }
}


output "public_ip" {
  value = aws_instance.app.public_ip
}

output "public_dns" {
  value = aws_instance.app.public_dns
}
