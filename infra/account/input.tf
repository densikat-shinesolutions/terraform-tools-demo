variable "aws_region" {}

variable "availability_zone" {}

variable "environment" {
  description = "The environment to create infrastructure in"
}


variable "stack_name" {
  description = "The name we want to use for creating resources"
}

variable "base_cidr_block" {
  description = "A /24 CIDR range definition"
  default     = "10.3.1.0/24"
}
