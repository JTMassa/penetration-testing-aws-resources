# ID used to connect to the EC2 instance through an approved method.
output "instance_id" {
  description = "EC2 instance ID for SSM or approved SSH access."
  value       = aws_instance.pentest.id
}

# Private network address of the testing instance.
output "private_ip" {
  description = "Private IP address of the testing instance."
  value       = aws_instance.pentest.private_ip
}

# Ready-to-use command for an approved SSM operator.
output "ssm_start_session_command" {
  description = "Command for an approved operator to start an SSM session."
  value       = "aws ssm start-session --target ${aws_instance.pentest.id} --region ${var.aws_region}"
}

# CloudWatch location for host activity logs.
output "cloudwatch_log_group" {
  description = "CloudWatch log group containing host activity logs."
  value       = aws_cloudwatch_log_group.host.name
}

# S3 location for CloudTrail audit records.
output "audit_bucket" {
  description = "CloudTrail audit bucket."
  value       = aws_s3_bucket.audit.id
}