### Create a Web Server and an Amazon RDS Database via Terraform

A common scenario includes an Amazon RDS DB instance in an Amazon VPC, that shares data with a Web server that is running in the same VPC. In this repo a VPC for this scenario is created. The following diagram shows this scenario

<p align="center">
  <img src="./pics/con-VPC-sec-grp.png" alt="Amazon RDS DB Instance" style="width: 250px;"/>
</p>

Inspriration for this repo came from this [tutorial;](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Tutorials.html) Create a Web Server and an Amazon RDS Database

This repository uses AWS provided modules from [Terraform Module Registry](https://registry.terraform.io/)

### Assumption
- It is assumed you are already familier with the tutorial mentioned in the reference section below
- You have installed Terraform >= v0.10.7
- AWS credentials are available at: "~/.aws/credentials"
```
[default]
aws_access_key_id = <KEY>
aws_secret_access_key = <SECRET>
```

### Instructions
```
git clone git@github.com:shazChaudhry/terraform-WebAppWithRDS.git && cd terraform-WebAppWithRDS
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Clean up
```
terraform show
terraform destroy -force
```
