resource "aws_network_interface" "main" {
  subnet_id   = data.aws_subnet.selected.id
  security_groups = [aws_security_group.service_sec_group.id]

  tags = {
    Name = "${var.stack_name}-${var.environment}-interface"
  }
}

resource "aws_security_group" "service_sec_group" {
  name = "${var.stack_name}-${var.environment}-sg"
  description = "Allow access to API"
  vpc_id = data.aws_vpc.selected.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.stack_name}-${var.environment}-sg"
  }
}

resource "aws_eip" "main_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.main.id
  tags = {
    Name = "${var.stack_name}-${var.environment}-eip"
  }
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.nano"

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  tags = {
    Name = "${var.stack_name}-${var.environment}-instance"
  }
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.name}"
  #user_data = "${file("scripts/userdata.sh")}"
  user_data = <<-EOT
    #!/bin/bash

    sudo apt-get update

    # Install SQLITE3
    sudo apt-get install -y sqlite3 unzip

    # Make sure SSM agent is started
    sudo snap start amazon-ssm-agent
    sudo snap services amazon-ssm-agent

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install Litestream
    wget https://github.com/benbjohnson/litestream/releases/download/v0.3.8/litestream-v0.3.8-linux-amd64.deb
    sudo dpkg -i litestream-v0.3.8-linux-amd64.deb

    # Install demo service
    sudo aws s3 cp s3://${aws_s3_bucket.service_bucket.bucket}/application/demoservice /home/ubuntu/demoservice
    sudo aws s3 cp s3://${aws_s3_bucket.service_bucket.bucket}/application/demoservice.service /etc/systemd/system/demoservice.service

    sudo chown ubuntu:ubuntu /home/ubuntu/demoservice
    sudo chmod +x /home/ubuntu/demoservice

    # Create and seed database if it doesn't exist
    aws s3api head-object --bucket ${aws_s3_bucket.service_bucket.bucket} --key application/dbcreated.flag || not_exist=true
    if [ $not_exist ]; then
      echo "it does not exist"
      sudo touch /home/ubuntu/images.db
      sudo aws s3 cp s3://${aws_s3_bucket.service_bucket.bucket}/application/createTable.sql /home/ubuntu/createTable.sql
      sudo cat /home/ubuntu/createTable.sql | sudo sqlite3 /home/ubuntu/images.db
      sudo chown ubuntu:ubuntu /home/ubuntu/images.db

      touch dbcreated.flag
      aws s3 cp dbcreated.flag s3://${aws_s3_bucket.service_bucket.bucket}/application/dbcreated.flag
    fi

    cat <<'EOF' >> /etc/litestream.yml
    dbs:
      - path: /home/ubuntu/images.db
        replicas:
          - url: s3://${aws_s3_bucket.service_bucket.bucket}/application/images.db
    EOF

    sudo systemctl enable litestream
    sudo systemctl start litestream

    sudo systemctl enable demoservice
    sudo systemctl start demoservice

    exit 0

  EOT

}

resource "aws_iam_role" "instance_role" {
  name = "${var.stack_name}-${var.environment}-role"
  tags = {
    Name = "${var.stack_name}-${var.environment}-role"
  }

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": {
    "Effect": "Allow",
    "Principal": {"Service": ["ec2.amazonaws.com","ssm.amazonaws.com"]},
    "Action": "sts:AssumeRole"
}
}
EOF
}

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.stack_name}-${var.environment}-instance"
  description = "Allows instance to interact with required resources in S3"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.stack_name}-${var.environment}-profile"
  tags = {
    Name = "${var.stack_name}-${var.environment}-profile"
  }
  role = "${aws_iam_role.instance_role.name}"
}

resource "aws_s3_bucket" "service_bucket" {
  bucket = "${var.stack_name}-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "${var.stack_name}-${var.environment}"
  }
}

resource "aws_s3_object" "service_binary" {
  bucket = aws_s3_bucket.service_bucket.bucket
  key    = "application/demoservice"
  source = "../../service/demoservice"

  etag = filemd5("../../service/demoservice")
}

resource "aws_s3_object" "systemd_service_file" {
  bucket = aws_s3_bucket.service_bucket.bucket
  key    = "application/demoservice.service"
  source = "../../service/demoservice.service"

  etag = filemd5("../../service/demoservice.service")
}

resource "aws_s3_object" "create_table_file" {
  bucket = aws_s3_bucket.service_bucket.bucket
  key    = "application/createTable.sql"
  source = "../../service/createTable.sql"

  etag = filemd5("../../service/createTable.sql")
}
