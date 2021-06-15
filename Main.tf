  provider "aws" {
        access_key = var.access_key
        secret_key = var.secret_key
        region = var.region
    }

    resource "aws_vpc" "vpc" {
        cidr_block = var.cidr_block_vpc
        instance_tenancy = "default"
        tags = {
        name = "${var.tag}-vpc"
        }
    }
    
    # section for the subnet
    resource "aws_subnet" "subnet" {
        vpc_id            = aws_vpc.vpc.id
        cidr_block        = var.cidr_block_subnet
        availability_zone = var.availability_zone
    
        tags = {
        name = "${var.tag}-subnet"
        }
    }
    
    # section for the internet_gateway
    resource "aws_internet_gateway" "igw" {
        vpc_id = aws_vpc.vpc.id
    
        tags = {
        name = "${var.tag}-IGW"
        }
    }
    
    
    # section for the routing table
    resource "aws_route_table" "route_table" {
        vpc_id = aws_vpc.vpc.id
    
        route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
        }
        tags = {
        name = "${var.tag}-route-table"
        }
    }
    
    
    # section for the route table
    resource "aws_route_table_association" "route_table_association" {
        subnet_id      = aws_subnet.subnet.id
        route_table_id = aws_route_table.route_table.id
    }
    
    # section for the security group
    
    resource "aws_security_group" "security_group_access_internet" {
        name        = "${var.tag}-security-group"
        description = "Allow TLS inbound traffic"
        vpc_id      = aws_vpc.vpc.id
    
        ingress {
        description      = "access_internet"
        from_port        = 0
        to_port          = 0
        protocol         = "all"
        # source           = var.my_ip
        cidr_blocks      = [var.my_ip]
        # ipv6_cidr_blocks = [aws_vpc.my_vpc.ipv6_cidr_block]
        }
    
        egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        }
    
        tags = {
        product = var.tag
        }
    }
    
    
    
    # # section for the EC2
    resource "aws_instance" "ec2_production" {
        # count         = "${var.ec2_instance_count}"
        ami           = var.ami
        availability_zone = var.availability_zone
        instance_type =  var.ec2_instance_type
        subnet_id = aws_subnet.subnet.id
        associate_public_ip_address = true
        vpc_security_group_ids = [aws_security_group.security_group_access_internet.id]
        # disable_api_termination = true
        key_name = "${var.tag}-key-pair"
        ebs_block_device {
        device_name = "/dev/sda1"
        volume_type = "gp2"
        volume_size = var.root_volume_size
        }
        tags = {
        Name = "${var.tag}-ec2"
        }
        
        provisioner "remote-exec" {
        inline = [
            "sudo apt-get update",
            "sudo sudo apt-get install git",
            "git clone https://username:password@github.com/repo/folder"
        ]
        }
    
        connection {
        type        = "ssh"
        user        = "ubuntu"
        password    = "password"
        private_key = file(var.keyPath)
        host        = self.public_ip
        timeout = "30s"
        }
        
    }
    
    # section for the EBS volume of different sizes and root volume not included here
    resource "aws_ebs_volume" "ebs_volume" {
        for_each = {
        0 = var.data_volume_size
        }
        availability_zone = var.availability_zone
        size              = each.value
        type              = "gp2"
        tags = {
        name = "${var.tag}-ebs-volume"
        }
    }
    
    # section for the EBS volume attachment
    
    resource "aws_volume_attachment" "volume_attachement" {
        count       = var.ebs_volume_count
        volume_id   = aws_ebs_volume.ebs_volume[count.index].id
        device_name = "${element(var.ec2_device_names, count.index)}"
        instance_id = aws_instance.ec2_production.id
    }
    
    # section for the aws_key_pair 
    resource "aws_key_pair" "key_pair" {
        key_name   = "${var.tag}-key-pair"
        public_key = var.key_pair
        tags = {
        name = "${var.tag}-key-pair"
        }
    }
    
    
