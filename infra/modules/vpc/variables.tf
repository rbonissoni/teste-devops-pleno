variable "name" {
  type    = string
  default = "devops-pleno"
}

variable "cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "pub_subnet" {
  type    = string
  default = "10.20.1.0/24"
}
