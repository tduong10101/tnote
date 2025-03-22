variable "db_pass" {
  sensitive = true
  type      = string
}
variable "aws_region" {
  type        = string
  description = "aws region"
  default     = "ap-southeast-2"
}
variable "namespace" {
  type        = string
  description = "namespace"
}
variable "stage" {
  type        = string
  description = "stage"
}

variable "r53_zone_name" {
  type        = string
  description = "aws route 53 zone name"
}

variable "acm_cert_domain" {
  type        = string
  description = "aws acm certificate domain"
}
variable "db_secret" {
  type        = string
  sensitive   = true
}
