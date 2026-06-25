data "aws_ami" "amazon_linux" {

  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "project3-vpc"
  }
}

resource "aws_subnet" "public" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "project3-subnet"
  }
}

resource "aws_security_group" "ec2_sg" {

  name = "project3-sg"

  vpc_id = aws_vpc.main.id

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server" {

  ami = data.aws_ami.amazon_linux.id

  instance_type = "t4g.small"

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  user_data = file("userdata.sh")

  tags = {
    Name = "project3-server"
  }
}

resource "aws_cloudwatch_log_group" "flowlogs" {

  name = "project3-flowlogs"
}

resource "aws_iam_role" "flowlogs_role" {

  name = "project3-flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = "sts:AssumeRole"

      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "flowlogs_policy" {

  name = "project3-flowlogs-policy"

  role = aws_iam_role.flowlogs_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]

      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow_logs" {

  iam_role_arn = aws_iam_role.flowlogs_role.arn

  log_destination = aws_cloudwatch_log_group.flowlogs.arn

  traffic_type = "ALL"

  vpc_id = aws_vpc.main.id
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {

  alarm_name = "project3-cpu-alarm"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1

  metric_name = "CPUUtilization"

  namespace = "AWS/EC2"

  period = 60

  statistic = "Average"

  threshold = 70

  alarm_description = "CPU Alarm Above 70 Percent"

  dimensions = {
    InstanceId = aws_instance.server.id
  }
}