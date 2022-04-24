output "instance_public_ip" {
  value = aws_eip.main_eip.public_ip
}

output "service_bucket" {
  value = aws_s3_bucket.service_bucket.bucket
}
