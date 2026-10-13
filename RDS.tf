resource "aws_db_subnet_group" "DBS_Tigre_ble" {
  name       = "${var.project_name}-inventory-subnet-group"
  subnet_ids = [aws_subnet.prive_Tigre_ble1.id, aws_subnet.prive_Tigre_ble2.id]
}

resource "aws_db_instance" "DI_Tigre_ble" {
  allocated_storage       = 20
  backup_retention_period = 1
  db_subnet_group_name    = aws_db_subnet_group.DBS_Tigre_ble.id
  engine                  = "mysql"
  engine_version          = "8.0"
  identifier              = "${var.project_name}-db"
  instance_class          = "db.t3.micro"
  password                = var.db_password
  username                = var.db_user
  db_name                 = "inquiries"
  vpc_security_group_ids  = [aws_security_group.sg_Tigre_ble_rds.id]
  skip_final_snapshot     = true


  storage_encrypted = true
  kms_key_id        = aws_kms_key.Tigre_ble_rds.arn
}


resource "aws_kms_key" "Tigre_ble_rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
      },
      {
        Sid    = "AllowEC2"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_Tigre_ble.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
      },
      {
        Sid    = "AllowLambda"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role_Tigre_ble.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
      }
    ]
  })
}