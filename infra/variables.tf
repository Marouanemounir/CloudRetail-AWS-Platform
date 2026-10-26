variable "aws_region" {
  type = string
  default = "eu-west-3"
}
variable "project_name" {
  type = string
  default = "cloudretail"
}
variable "environment" {
  type = string
  default = "demo"
}
variable "github_repository" {
  type = string
  description = "owner/repo, e.g. YOUR_USER/CloudRetail-AWS-Platform"
}
variable "db_instance_class" {
  type = string
  default = "db.t4g.micro"
}
variable "db_multi_az" {
  type = bool
  default = false
  description = "True increases availability AND costs"
}
variable "desired_count" {
  type = number
  default = 0
  description = "Bootstrap 0; GitHub deployment scales to 2"
}
