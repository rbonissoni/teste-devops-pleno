module "vpc" {
  source     = "../../modules/vpc"
  name       = "devops-pleno"
  cidr_block = "10.30.0.0/16"
  pub_subnet = "10.30.1.0/24"
}

module "ec2" {
  source          = "../../modules/ec2"
  name            = "devops-pleno"
  subnet_id       = module.vpc.subnet_id
  instance_type   = var.instance_type
  key_name        = var.key_name
  enable_jenkins  = var.enable_jenkins
  repo_url        = var.repo_url
  repo_branch     = var.repo_branch
  dd_api_key      = var.dd_api_key
  dd_site         = var.dd_site
  dd_app_key      = var.dd_app_key
}

output "ec2_public_ip" {
  value = module.ec2.public_ip
}

output "ec2_public_dns" {
  value = module.ec2.public_dns
}

output "jenkins_url" {
  value = var.enable_jenkins ? "http://${module.ec2.public_ip}:8080" : ""
}
