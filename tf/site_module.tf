module "site" {
  source = "./modules/site"

  name        = "site"
  domain_name = "rrv.sh"
  image       = "ghcr.io/rrvsh/site:latest"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  container_port   = 80
  cpu              = 256
  memory           = 512
  desired_count    = 1
  assign_public_ip = true
  environment = {
    PORT = "80"
  }
}
