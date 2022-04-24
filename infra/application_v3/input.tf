variable aws_region {}
variable vpc_name {}
variable subnet_name {}


variable "environment" {
  description = "The environment to create infrastructure in"
}

variable "stack_name" {
  description = "The name we want to use for creating resources"
}

variable "force_bucket_destroy" {
  description = "Whether to force destroy the S3 bucket"
  default = false
}
