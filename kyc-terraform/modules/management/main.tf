resource "aws_instance" "jenkins" {
  ami           = var.ami_id
  instance_type = "t3.medium"
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name      = var.key_name

  tags = {
    Name = "${var.environment}-jenkins-server"
    Role = "jenkins"
  }
}

resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name      = var.key_name

  tags = {
    Name = "${var.environment}-bastion-host"
    Role = "bastion"
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.environment}-build-artifacts-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
