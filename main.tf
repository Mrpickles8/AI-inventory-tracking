terraform {
  required_version = "1.16.5"
  cloud {
    organization = "Dominionorg"
    workspaces {
      name = "AI-inventory-tracking"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}


provider "aws" {
  region = var.aws_region
}


resource "aws_vpc" "Tigre_ble" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_subnet" "public_Tigre_ble" {
  vpc_id                  = aws_vpc.Tigre_ble.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
}

resource "aws_subnet" "prive_Tigre_ble1" {
  vpc_id                  = aws_vpc.Tigre_ble.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"
}


resource "aws_subnet" "prive_Tigre_ble2" {
  vpc_id                  = aws_vpc.Tigre_ble.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"
}


resource "aws_internet_gateway" "Igw_Tigre_ble" {
  vpc_id = aws_vpc.Tigre_ble.id
}

resource "aws_route_table" "Rt_public_Tigre_ble" {
  vpc_id = aws_vpc.Tigre_ble.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Igw_Tigre_ble.id
  }
}


resource "aws_route_table_association" "Rt_ass_public_Tigre_ble" {
  subnet_id      = aws_subnet.public_Tigre_ble.id
  route_table_id = aws_route_table.Rt_public_Tigre_ble.id
}


resource "aws_network_acl" "NACL_PUBLIC" {
  vpc_id     = aws_vpc.Tigre_ble.id
  subnet_ids = [aws_subnet.public_Tigre_ble.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 160
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}



resource "aws_network_acl" "NACL_PRIVE1" {
  vpc_id     = aws_vpc.Tigre_ble.id
  subnet_ids = [aws_subnet.prive_Tigre_ble1.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.2.0/24"
    from_port  = 3306
    to_port    = 3306
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "10.0.2.0/24"
    from_port  = 1024
    to_port    = 65535
  }
}


resource "aws_network_acl" "NACL_PRIVE2" {
  vpc_id     = aws_vpc.Tigre_ble.id
  subnet_ids = [aws_subnet.prive_Tigre_ble2.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.3.0/24"
    from_port  = 3306
    to_port    = 3306
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "10.0.3.0/24"
    from_port  = 1024
    to_port    = 65535
  }
}


resource "aws_security_group" "sg_Tigre_ble_ec2" {
  vpc_id = aws_vpc.Tigre_ble.id


  ingress {
    from_port   = 8080
    to_port     = 8080
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
    from_port   = 443
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

resource "aws_security_group" "sg_Tigre_ble_rds" {
  vpc_id = aws_vpc.Tigre_ble.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_Tigre_ble_ec2.id]
  }
}


resource "aws_iam_instance_profile" "Iam_inst_prof_Tigre_ble" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_Tigre_ble.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.18-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_instance" "app_tigre_bleu" {
  ami                    = data.aws_ami.ami_Tigre_bleu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_Tigre_ble.id
  vpc_security_group_ids = [aws_security_group.sg_Tigre_ble_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.Iam_inst_prof_Tigre_ble.name

  user_data = <<-EOF
    #!/bin/bash
    # Mise à jour du système et installation de Python
    yum update -y && yum install -y python3 python3-pip

    # Installation des dépendances applicatives
    pip3 install flask boto3 pymysql

    # Création de l'application Flask
    cat > /home/ec2-user/app.py << 'APPEOF'
    import boto3
    import json
    import pymysql
    from flask import Flask, request, jsonify

    app = Flask(__name__)

    def get_db():
        return pymysql.connect(
            host='${aws_db_instance.DI_Tigre_ble.endpoint}'.split(':')[0],
            user='admin',
            password='${var.db_password}',
            database='inventory',
            cursorclass=pymysql.cursors.DictCursor
        )

    @app.route('/health', methods=['GET'])
    def health_check():
        return jsonify({'status': 'healthy'}), 200

    @app.route('/products', methods=['GET'])
    def get_products():
        db = get_db()
        with db.cursor() as cursor:
            cursor.execute('SELECT * FROM products')
            return jsonify(cursor.fetchall())

    @app.route('/products', methods=['POST'])
    def add_product():
        data = request.json
        db = get_db()
        with db.cursor() as cursor:
            cursor.execute(
                'INSERT INTO products (name, quantity, price) VALUES (%s, %s, %s)',
                (data['name'], data['quantity'], data['price'])
            )
        db.commit()
        return jsonify({'status': 'created'}), 201

    if __name__ == '__main__':
        # Configuration sur le port 8080 pour la pipeline CI/CD
        app.run(host='0.0.0.0', port=8080)
    APPEOF

    # Lancement de l'application en arrière-plan
    python3 /home/ec2-user/app.py &
  EOF
}





data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_analysis.py"
  output_path = "lamnda_analysis.zip"
}


resource "aws_lambda_function" "TB_lambda_function" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-inventory-analysis"
  role             = aws_iam_role.lambda_role_Tigre_ble.arn
  handler          = "lambda_analysis.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.13"

  environment {
    variables = {
      DB_HOST      = aws_db_instance.DI_Tigre_ble.endpoint
      DB_PASSWORD  = var.db_password
      SENDER_EMAIL = var.admin_email
      ADMIN_EMAIL  = var.admin_email
    }
  }
}


resource "aws_cloudwatch_event_rule" "TB_events_rule" {
  name                = "${var.project_name}-inventory-events-rule"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "TB_events_target" {
  rule = aws_cloudwatch_event_rule.TB_events_rule.id
  arn  = aws_lambda_function.TB_lambda_function.arn
}


resource "aws_lambda_permission" "allow_analysis_inventory" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.TB_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.TB_events_rule.arn
}

output "app_url" {
  value = "http://${aws_instance.app_tigre_bleu.public_ip}"
}

output "db_endpoint" {
  value = aws_db_instance.DI_Tigre_ble.endpoint
}

output "mon_ec2_sg_id" {
  value       = aws_security_group.sg_Tigre_ble_ec2.id
  description = "L'ID du Security Group genere dynamiquement"
}

output "app_tigre_bleu_ip" {
  value = aws_instance.app_tigre_bleu.public_ip
}
