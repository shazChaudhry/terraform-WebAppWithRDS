### Create a Web Server and an Amazon RDS Database via Terraform

A common scenario includes an Amazon RDS DB instance in an Amazon VPC, that shares data with a Web server that is running in the same VPC. In this repo a VPC for this scenario is created. The following diagram shows this scenario

<p align="center">
  <img src="./pics/con-VPC-sec-grp.png" alt="Amazon RDS DB Instance" style="width: 250px;"/>
</p>

Inspriration for this repo came from this [tutorial](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Tutorials.html); Create a Web Server and an Amazon RDS Database.

This solution has been tested on CentOS 7.4:
- You may use the provided Vagrantfile for testing the solution locally if you like
- Not tested on Windows but as per the documentation [here](https://www.terraform.io/docs/provisioners/connection.html#agent) you will need to use [Pageant](http://the.earth.li/~sgtatham/putty/0.66/htmldoc/Chapter9.html#pageant) as an SSH authentication agent

This repository uses AWS provided modules from [Terraform Module Registry](https://registry.terraform.io/)

### Assumption
- You have installed Terraform version which is >= 0.11.8
- You are using CentOS 7.4
- .PEM key is available under: "~/.ssh/". In my case it is called personal.pem
- AWS credentials are available at "~/.aws/credentials" which should look like as follows:
```
[default]
aws_access_key_id = <KEY>
aws_secret_access_key = <SECRET>
```

### Instructions
Please follow the instructions below to stand up Apache [HTTPD + MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/TUT_WebAppWithRDS.html) in AWS using Terraform:
```
eval $(ssh-agent)
ssh-add -k ~/.ssh/personal.pem
ssh-add -k ~/.ssh/id_rsa
git clone git@github.com:shazChaudhry/terraform-WebAppWithRDS.git && cd terraform-WebAppWithRDS
terraform init
terraform plan
terraform apply -auto-approve
```

### Testing
  - In your favorite web browser, navigate to http://YOUR_EC2_WEBSERVER/calldb.php _(you will need to check AWS console for the instance IP address)_
  - Refresh the page a few time and note that number of rows will be incremented

### Clean up
```
terraform show
terraform destroy -force
```
