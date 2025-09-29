variable "name" {
  type    = string
  default = "devops-pleno"
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
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

variable "dd_api_key" {
  type      = string
  sensitive = true
}

variable "dd_site" {
  type    = string
  default = "us5.datadoghq.com"
}

variable "dd_app_key" {
  type      = string
  sensitive = true
  default   = ""
}
