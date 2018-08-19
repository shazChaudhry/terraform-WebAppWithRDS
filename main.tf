provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "${var.credentials}"
  profile                 = "default"
  version                 = "~> 1.32"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.38.0"

  enable_dns_hostnames    = true
  enable_dns_support      = true
  enable_nat_gateway      = true
  map_public_ip_on_launch = true
  enable_dhcp_options     = true
  single_nat_gateway      = true

  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.0.0/24"]

  dhcp_options_domain_name         = "${var.DnsZoneName}"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  dhcp_options_tags = {
    Name = "Internal_DHCP"
  }

  vpc_tags = {
    Name = "CI-VPC"
  }

  public_subnet_tags = {
    Name = "public_subnets"
  }

  public_route_table_tags = {
    Name = "public_route_table"
  }

  private_subnet_tags = {
    Name = "private_subnet"
  }

  private_route_table_tags = {
    Name = "private_route_table"
  }

  nat_gateway_tags = {
    Name = "nat_gateway"
  }

  nat_eip_tags = {
    Name = "nat_eip"
  }

  igw_tags = {
    Name = "igw"
  }

  tags = {
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
    Terraform   = "true"
  }
}

resource "aws_route53_zone" "main" {
  name    = "${var.DnsZoneName}"
  vpc_id  = "${module.vpc.vpc_id}"
  comment = "private hosted zone"

  tags {
    Name = "route53_zone"
  }
}

module "DB_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.1.0"

  name                = "WebApp_db_sg"
  description         = "Security Group for MySQL"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = ["10.0.0.0/24"]
  ingress_rules       = ["mysql-tcp", "ssh-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]

  tags = {
    Name = "DB_sg"
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "1.21.0"

  allocated_storage         = 20
  engine                    = "mysql"
  username                  = "webapp"
  password                  = "Password01"
  engine_version            = "5.7.22"
  identifier                = "webappdb"
  instance_class            = "db.t2.micro"
  name                      = "webapp"
  port                      = "3306"
  copy_tags_to_snapshot     = true
  family                    = "mysql5.7"
  major_engine_version      = "5.7"
  # skip_final_snapshot       = false
  # final_snapshot_identifier = "webappdb-final"

  # Specifies whether or not to create this database from a snapshot.
  # This correlates to the snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05.
  # snapshot_identifier = webappdb-final
  subnet_ids = ["${module.vpc.private_subnets}"]

  vpc_security_group_ids = ["${module.DB_sg.this_security_group_id}"]

  allow_major_version_upgrade = true
  auto_minor_version_upgrade  = true
  backup_retention_period     = 5
  backup_window               = "03:00-06:00"
  maintenance_window          = "Mon:00:00-Mon:03:00"

  iam_database_authentication_enabled = true

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

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]

  tags = {
    Name        = "mysql"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }
}

# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html?shortFooter=true#rrsets-values-weighted-name
resource "aws_route53_record" "db" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "mysql.${var.DnsZoneName}"
  type    = "CNAME"
  ttl     = "5"

  weighted_routing_policy {
    weight = 0
  }

  set_identifier = "mysql"
  records        = ["${module.rds.this_db_instance_address}"]
}

module "WebApp_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.1.0"

  name                = "WebApp_sg"
  description         = "Security Group for WebApp"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp", "ssh-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]

  tags = {
    Name = "WebApp_sg"
  }
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

module "WebServer" {
  source = "terraform-aws-modules/ec2-instance/aws"

  ami                         = "${data.aws_ami.ami.id}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "shaz"
  name                        = "webbapp"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${module.WebApp_sg.this_security_group_id}"]
  key_name                    = "personal"
  subnet_id                   = "${module.vpc.public_subnets[0]}"

  tags = {
    Name        = "webbapp"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }

  volume_tags = {
    Name        = "webbapp_volume"
    Owner       = "${var.tags[0]}"
    Environment = "${var.tags[1]}"
  }

  # The user data to provide when launching the instance
  user_data = <<HEREDOC
  #!/bin/bash
  yum update -y
  yum install -y httpd24 php56 php56-mysqlnd
  service httpd start
  chkconfig httpd on
  groupadd www
  usermod -a -G www ec2-user
  chown -R root:www /var/www
  chmod 2775 /var/www
  find /var/www -type d -exec sudo chmod 2775 {} +
  find /var/www -type f -exec sudo chmod 0664 {} +
  echo "<?php" >> /var/www/html/calldb.php
  echo "\$conn = new mysqli('webappdb.c9oyxmgvbt66.eu-west-2.rds.amazonaws.com', 'webapp', 'Password01', 'webapp');" >> /var/www/html/calldb.php
  echo "\$sql1 = 'CREATE TABLE mytable (mycol varchar(255))'; " >> /var/www/html/calldb.php
  echo "\$conn->query(\$sql1); " >>  /var/www/html/calldb.php
  echo "\$sql2 = 'INSERT INTO mytable (mycol) values ('linuxacademythebest')'; " >> /var/www/html/calldb.php
  echo "\$conn->query(\$sql2); " >>  /var/www/html/calldb.php
  echo "\$sql3 = 'SELECT * FROM mytable'; " >> /var/www/html/calldb.php
  echo "\$result = \$conn->query(\$sql3); " >>  /var/www/html/calldb.php
  echo "while(\$row = \$result->fetch_assoc()) { echo 'the value is: ' . \$row['mycol'] ;} " >> /var/www/html/calldb.php
  echo "\$conn->close(); " >> /var/www/html/calldb.php
  echo "?>" >> /var/www/html/calldb.php
HEREDOC
}

terraform {
  required_version = ">= 0.11.8"

  # It is expected that the bucket already exists
  # backend "s3" {
  #   bucket  = "ci.terraform"
  #   key     = "dev/terraform.tfstate"
  #   region  = "eu-west-2"
  #   encrypt = true
  # }
}
