resource "aws_iam_policy" "boundary" {
  name        = "${var.project_name}-permissions-boundary"
  description = "Permissions boundary for ${var.project_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"]
      },
      {
        Sid      = "SesSendEmail"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["arn:aws:ses:eu-west-1:${data.aws_caller_identity.current.account_id}:identity/${var.admin_email}"]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/*"]
      },
      {
        Sid      = "KmsDataAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = ["arn:aws:kms:eu-west-1:${data.aws_caller_identity.current.account_id}:key/*"]
      },
      {
        Sid    = "SystemsManager"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:ListInstanceAssociations",
          "ssm:DescribeInstanceProperties"
        ]
        Resource = ["arn:aws:ec2:eu-west-1:${data.aws_caller_identity.current.account_id}:instance/*"]
      },
      {
        Sid    = "SsmMessages"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = ["*"]
        # SSM messages n'a pas d'ARN spécifique — * obligatoire ici
      },
      {
        Sid    = "Ec2Messages"
        Effect = "Allow"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = ["*"]
        # ec2messages n'a pas d'ARN spécifique — * obligatoire ici
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2_Tigre_ble" {
  name                 = "${var.project_name}-ec2-role"
  permissions_boundary = aws_iam_policy.boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Sid       = ""
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_Tigre_ble_authorisation" {
  role = aws_iam_role.ec2_Tigre_ble.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"]
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["arn:aws:ses:eu-west-1:${data.aws_caller_identity.current.account_id}:identity/${var.admin_email}"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.Tigre_ble_rds.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_Tigre_ble.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "lambda_boundary" {
  name        = "${var.project_name}-lambda-permissions-boundary"
  description = "Permissions boundary for the inventory reporting Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
      },
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"]
      },
      {
        Sid      = "SesSendReport"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["arn:aws:ses:eu-west-1:${data.aws_caller_identity.current.account_id}:identity/${var.admin_email}"]
      },
      {
        Sid      = "RdsIamAuthentication"
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = ["arn:aws:rds-db:eu-west-1:${data.aws_caller_identity.current.account_id}:dbuser:*/*"]
      },
      {
        Sid      = "KmsEncryption"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = ["arn:aws:kms:eu-west-1:${data.aws_caller_identity.current.account_id}:key/*"]
      }
    ]
  })
}

resource "aws_iam_role" "lambda_role_Tigre_ble" {
  name                 = "${var.project_name}-lambda-role"
  permissions_boundary = aws_iam_policy.lambda_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Sid       = ""
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role_Tigre_ble.id # ← corrigé

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"]
      },
      {
        Sid      = "SesSendEmail"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["arn:aws:ses:eu-west-1:${data.aws_caller_identity.current.account_id}:identity/${var.admin_email}"]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:eu-west-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.Tigre_ble_rds.arn]
      }
    ]
  })
}