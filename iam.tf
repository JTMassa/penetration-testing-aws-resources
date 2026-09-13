# IAM role assumed by the EC2 instance.
resource "aws_iam_role" "pentest" {
  name = "${var.project_name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Grants the instance access to AWS Systems Manager.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.pentest.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Grants only the CloudWatch permissions needed to publish host logs.
resource "aws_iam_role_policy" "logging" {
  name = "${var.project_name}-logging"
  role = aws_iam_role.pentest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.host.arn}:*"
    }]
  })
}

# Lets EC2 use the IAM role above.
resource "aws_iam_instance_profile" "pentest" {
  name = "${var.project_name}-instance"
  role = aws_iam_role.pentest.name
}