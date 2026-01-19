provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "ec2_sg" {
  name   = var.sg_name_ec2
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow 9000"
    from_port   = 9000
    to_port     = 9000
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


resource "aws_security_group" "rds_sg" {
  name   = var.sg_name_rds
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  root_block_device {
    volume_size = var.instance_disk_size
    encrypted   = true
  }

  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = var.ec2_name
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              apt update -y
              apt upgrade -y
              apt install ca-certificates curl gnupg lsb-release postgresql-client -y

              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg

              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

              apt update -y
              apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

              systemctl enable docker
              systemctl start docker

              usermod -aG docker ubuntu
              git clone https://github.com/DefectDojo/django-DefectDojo.git
              cd django-DefectDojo
              docker compose up -d
              docker run -d --name sonarqube -p 9000:9000 -p 9092:9092 -v sonarqube-conf:/opt/sonarqube/conf -v sonarqube-data:/opt/sonarqube/data -v sonarqube-logs:/opt/sonarqube/logs -v sonarqube-extensions:/opt/sonarqube/extensions sonarqube
              EOF
}

resource "aws_db_subnet_group" "subnet_group" {
  name       = var.secure_subnet_name
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "postgres" {

  identifier = var.db_name

  allocated_storage = var.db_storage
  engine            = "postgres"
  instance_class    = var.db_instance_class
  db_name           = "appdb"
  username          = var.db_username
  password          = var.db_password

  publicly_accessible = false
  storage_encrypted   = true
  deletion_protection = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name

  skip_final_snapshot = false
}

resource "null_resource" "run_sql" {
  depends_on = [
    aws_instance.ec2,
    aws_db_instance.postgres
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_file)
    host        = aws_instance.ec2.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/../sql/create_databases.sql"
    destination = "/home/ubuntu/create_databases.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Waiting for RDS...'",

      # Exportar password ANTES
      "export PGPASSWORD='${var.db_password}'",

      # Esperar conexión real a postgres
      "until psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d postgres -c '\\q' 2>/dev/null; do sleep 5; done",

      "echo 'RDS ready, running SQL script...'",

      # Ejecutar script
      "psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d postgres -f /home/ubuntu/create_databases.sql"
    ]
  }

}
