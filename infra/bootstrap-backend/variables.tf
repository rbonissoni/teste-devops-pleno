variable "region" {
  type = string
}

variable "bucket_name" {
  type    = string
  default = "renan-bonissoni-terraform"
}

variable "dynamodb_table" {
  type    = string
  default = "tfstate-lock-devops-pleno"
}
