# Shared resource tags and rendered EC2 startup configuration.
locals {
  common_tags = merge({
    Project        = var.project_name
    Owner          = var.owner
    Purpose        = var.purpose
    ExpirationDate = var.expiration_date
    ManagedBy      = "terraform"
  }, var.extra_tags)

  user_data = templatefile("${path.module}/user-data.sh", {
    testers        = var.testers
    log_group_name = aws_cloudwatch_log_group.host.name
  })
}

# Finds the latest Amazon Linux 2023 AMI when no AMI is provided.
data "aws_ami" "amazon_linux" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Reads the AWS account ID for audit resource names and policies.
data "aws_caller_identity" "current" {}

# Stores host activity logs with a defined retention period.
resource "aws_cloudwatch_log_group" "host" {
  name              = "/pentest/${var.project_name}/host"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logging.arn
  depends_on        = [aws_kms_key_policy.logging]
}

# Encrypts host logs and audit data with a customer-managed key.
resource "aws_kms_key" "logging" {
  description         = "KMS key for ${var.project_name} host logs"
  enable_key_rotation = true
}

# Allows CloudWatch Logs and CloudTrail to use the logging encryption key.
resource "aws_kms_key_policy" "logging" {
  key_id = aws_kms_key.logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountAdministration"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
      }, {
      Sid    = "AllowCloudWatchLogs"
      Effect = "Allow"
      Principal = {
        Service = "logs.${var.aws_region}.amazonaws.com"
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
      Condition = {
        ArnLike = {
          "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/pentest/${var.project_name}/*"
        }
      }
      }, {
      Sid    = "AllowCloudTrail"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = [
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}"
        }
      }
    }]
  })
}

# Gives the logging key a readable alias.
resource "aws_kms_alias" "logging" {
  name          = "alias/${var.project_name}-logs"
  target_key_id = aws_kms_key.logging.key_id
}

# Restricts inbound access and permits required outbound connections.
resource "aws_security_group" "pentest" {
  name        = "${var.project_name}-access"
  description = "Restricted access for the temporary penetration testing instance"
  vpc_id      = var.vpc_id

  # Adds SSH rules only for explicitly approved source CIDRs.
  dynamic "ingress" {
    for_each = var.enable_ssh ? var.allowed_ssh_cidr_blocks : []

    content {
      description = "Approved vendor SSH source"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Allows the instance to reach SSM and approved package repositories.
  egress {
    description = "Required outbound access for approved packages and SSM"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-access" }
}

# Runs the temporary Linux testing environment.
resource "aws_instance" "pentest" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.pentest.id]
  iam_instance_profile        = aws_iam_instance_profile.pentest.name
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # Encrypts the operating-system disk.
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 30
  }

  tags = { Name = var.project_name }
}

# Provides encrypted space for tools and test results.
resource "aws_ebs_volume" "tools" {
  availability_zone = aws_instance.pentest.availability_zone
  encrypted         = true
  kms_key_id        = aws_kms_key.storage.arn
  type              = "gp3"
  size              = var.tool_volume_size_gib

  tags = { Name = "${var.project_name}-tools" }
}

# Attaches the tools volume to the EC2 instance.
resource "aws_volume_attachment" "tools" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.tools.id
  instance_id = aws_instance.pentest.id
}

# Encrypts the tools and test-output volume.
resource "aws_kms_key" "storage" {
  description         = "KMS key for ${var.project_name} encrypted storage"
  enable_key_rotation = true
}

# Gives the storage key a readable alias.
resource "aws_kms_alias" "storage" {
  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage.key_id
}

# Records AWS API activity for the engagement.
resource "aws_cloudtrail" "pentest" {
  name                          = var.project_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.audit]
}

# Stores CloudTrail audit files in a dedicated bucket.
resource "aws_s3_bucket" "audit" {
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # allows the bucket to be deleted even if it contains objects, which is useful for temporary environments.

  tags = { Name = "${var.project_name}-audit" }
}

# Prevents public access to the audit bucket.
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enables customer-managed encryption for audit files.
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  # Applies KMS encryption to new objects by default.
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logging.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Allows CloudTrail to write audit files while keeping the bucket private.
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSCloudTrailWrite"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl"  = "bucket-owner-full-control"
          "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}"
        }
      }
      }, {
      Sid       = "AWSCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:GetBucketAcl"
      Resource  = aws_s3_bucket.audit.arn
      Condition = {
        StringEquals = {
          "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}"
        }
      }
    }]
  })
}