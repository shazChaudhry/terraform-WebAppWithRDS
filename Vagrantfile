# -*- mode: ruby -*-
# vi: set ft=ruby :

$install_terraform = <<SCRIPT
yum install -y zip unzip
curl -O https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
unzip terraform_0.11.8_linux_amd64.zip -d /usr/bin/
terraform --version
rm -f *.zip
SCRIPT

Vagrant.configure("2") do |config|
	config.vm.box = "bento/centos-7.4"
	config.hostmanager.enabled = true
	config.hostmanager.manage_host = true
	config.hostmanager.manage_guest = true

	config.vm.define "node1", primary: true do |node1|
		node1.vm.hostname = 'node1'
		node1.vm.network :private_network, ip: "192.168.99.101"
		node1.vm.provider :virtualbox do |v|
			v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
			v.customize ["modifyvm", :id, "--memory", 4000]
			v.customize ["modifyvm", :id, "--name", "node1"]
		end
    node1.vm.provision "file", source: "~/.ssh", destination: "$HOME/.ssh"
    node1.vm.provision "shell", inline: "chmod 600 /home/vagrant/.ssh/*"
    node1.vm.provision "file", source: "~/.aws", destination: "$HOME/.aws"
    node1.vm.provision "shell", inline: "chmod 600 /home/vagrant/.aws/*"
    node1.vm.provision :shell, inline: $install_terraform
	end
end
