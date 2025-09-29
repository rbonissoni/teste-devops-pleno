variable "region" {
  type    = string
  default = "us-east-1"
}

variable "key_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "enable_jenkins" {
  type    = bool
  default = true
}

variable "repo_url" {
  type = string
}

variable "repo_branch" {
  type    = string
  default = "main"
}



variable "dd_site" {
  type = string
  # exemplo de valor: "datadoghq.com" ou "us5.datadoghq.com"
}

variable "dd_api_key" {
  type      = string
  sensitive = true
}
variable "dd_app_key" {
  type      = string
  sensitive = true
}
