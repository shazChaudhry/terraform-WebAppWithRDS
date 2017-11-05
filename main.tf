provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "${var.credentials}"
  profile                 = "default"
}

resource "aws_vpc_dhcp_options" "WepAppDHCP" {
  domain_name         = "${var.DnsZoneName}"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  azs                     = ["eu-west-2a", "eu-west-2b"]
  cidr                    = "10.0.0.0/16"
  enable_dns_hostnames    = true                           # Should be true if you want to use private DNS within the VPC
  enable_dns_support      = true                           # Should be true if you want to use private DNS within the VPC
  enable_nat_gateway      = true
  map_public_ip_on_launch = true
  name                    = "ci"                           # Name to be used on all the resources as identifier
  private_subnets         = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets          = ["10.0.0.0/24"]
  single_nat_gateway      = true                           # Should be true if you want to provision a single shared NAT Gateway across all of your private networks

  tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = "${module.vpc.vpc_id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.WepAppDHCP.id}"
}

resource "aws_route53_zone" "main" {
  name    = "${var.DnsZoneName}"
  vpc_id  = "${module.vpc.vpc_id}"
  comment = "private hosted main zone"

  tags {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

module "WebApp_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name                = "WebApp_sg"
  description         = "Security Group for WebApp"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp", "ssh-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]

  tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

module "DB_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name                = "WebApp_db_sg"
  description         = "Security Group for MySQL"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = ["10.0.0.0/24"]
  ingress_rules       = ["mysql-tcp", "ssh-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]

  tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  # Specifies whether or not to create this database from a snapshot. This correlates to the snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05
  # snapshot_identifier        = ""


  # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html
  #replicate_source_db        = ""

  allocated_storage         = 20                                         # Required unless a snapshot_identifier or replicate_source_db is provided
  engine                    = "mysql"                                    # Required unless a snapshot_identifier or replicate_source_db is provided
  username                  = "webapp"                                   # Required unless a snapshot_identifier or replicate_source_db is provided
  password                  = "Password01"                               # Required unless a snapshot_identifier or replicate_source_db is provided
  engine_version            = "5.7.19"
  identifier                = "webappdb"
  instance_class            = "db.t2.micro"
  name                      = "webapp"
  port                      = "3306"
  copy_tags_to_snapshot     = true
  family                    = "mysql5.7"
  skip_final_snapshot       = false
  final_snapshot_identifier = "webappdb-final"
  subnet_ids                = ["${module.vpc.private_subnets}"]
  vpc_security_group_ids    = ["${module.DB_sg.this_security_group_id}"]
  # apply_immediately          = true
  allow_major_version_upgrade = true
  auto_minor_version_upgrade  = true
  backup_retention_period     = 5
  backup_window               = "03:00-06:00"
  maintenance_window          = "Mon:00:00-Mon:03:00"
  parameters = [
    {
      name  = "character_set_client"
      value = "utf8"
    },
    {
      name  = "character_set_server"
      value = "utf8"
    },
  ]
  tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

resource "aws_db_snapshot" "snapshot" {
  db_instance_identifier = "${module.rds.this_db_instance_id}"
  db_snapshot_identifier = "webappdb"
}

# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html?shortFooter=true#rrsets-values-weighted-name
resource "aws_route53_record" "db" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "db"
  type    = "CNAME"
  ttl     = "5"

  weighted_routing_policy {
    weight = 0
  }

  set_identifier = "db"
  records        = ["${module.rds.this_db_instance_address}"]
}

# When we need to create an EC2 resource on AWS using Terraform, we need to specify the AMI id to get the correct image. The id is not easy to memorise and it changes depending on the zone we are working one. On every new release the id changes again. So, how can we be sure to get the correct ID for our region, of the latest image available for a given Linux distribution?

# Find the most recent image by visiting "LaunchInstanceWizard --> Community AMIs page and selecting operating system, architecture and root device type"
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["amazon"]
}

module "ec2-instance" "webapp" {
  source = "terraform-aws-modules/ec2-instance/aws"

  ami                         = "${data.aws_ami.ami.id}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "shaz"
  name                        = "WebApp"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.WebApp_sg.this_security_group_id}"]
  availability_zone           = "eu-west-2a"
  key_name                    = "personal"
  subnet_id                   = "${module.vpc.public_subnets[0]}"

  tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }

  volume_tags = {
    Name        = "${var.tags[1]}"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html?shortFooter=true#rrsets-values-weighted-name
resource "aws_route53_record" "wepapp" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "wepapp"
  type    = "CNAME"
  ttl     = "5"

  weighted_routing_policy {
    weight = 0
  }

  set_identifier = "wepapp"
  records        = ["${module.ec2-instance.private_dns}"]
}

# resource "aws_s3_bucket" "bucket" {
#   bucket    = "ci.terraform"
#   region    = "eu-west-2"
#   acl       = "private"
#
#   versioning {
#     enabled  = true
#   }
#
#   lifecycle {
#     prevent_destroy = false
#     ignore_changes = true
#   }
#
#   tags {
#     Name        = "terraform"
#     Environment = "webapp"
#   }
# }

# It is expected that the bucket already exists
terraform {
  backend "s3" {
    bucket  = "ci.terraform"
    key     = "dev/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}
