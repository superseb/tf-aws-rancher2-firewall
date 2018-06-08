provider "aws" {
  region = "${var.region}"
}

variable "region" {
  default = "eu-west-3"
}

variable "prefix" {
  default = "myname"
}

variable "cidr_block" {
  default = "10.200.100.0/24"
}

variable "rancher_version" {
  default = "v2.0.2"
}

variable "instance_size" {
  default = "t2.medium"
}

variable "key_name" {
  default = "yourkeyname"
}

variable "docker_version_server" {
  default = "17.03"
}

variable "docker_version_agent" {
  default = "17.03"
}

variable "count_etcd_nodes" {
  default = "1"
}

variable "count_controlplane_nodes" {
  default = "1"
}

variable "count_worker_nodes" {
  default = "1"
}

data "aws_ami" "ubuntuxenial" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block       = "${var.cidr_block}"
  instance_tenancy = "default"

  tags {
    Name = "${var.prefix}-main"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.prefix}-main"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_subnet" "rancher" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet("${var.cidr_block}", 2, 0)}"

  tags {
    Name = "${var.prefix}-subnet-rancher"
  }
}

resource "aws_subnet" "etcd" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet("${var.cidr_block}", 2, 1)}"

  tags {
    Name = "${var.prefix}-subnet-etcd"
  }
}

resource "aws_subnet" "controlplane" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet("${var.cidr_block}", 2, 2)}"

  tags {
    Name = "${var.prefix}-subnet-controlplane"
  }
}

resource "aws_subnet" "worker" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet("${var.cidr_block}", 2, 3)}"

  tags {
    Name = "${var.prefix}-subnet-worker"
  }
}

resource "aws_security_group" "rancher" {
  name        = "${var.prefix}-rancher"
  description = "rancher nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "etcd" {
  name        = "${var.prefix}-etcd"
  description = "etcd nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = false
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = false
  }

  egress {
    from_port       = 2379
    to_port         = 2380
    protocol        = "tcp"
    security_groups = []
    self            = true
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "controlplane" {
  name        = "${var.prefix}-control"
  description = "controlplane nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.rancher.cidr_block}", "${aws_subnet.etcd.cidr_block}", "${aws_subnet.controlplane.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}", "${aws_subnet.controlplane.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = []
    self            = true
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}"]
    self        = false
  }

  egress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}", "${aws_subnet.controlplane.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker" {
  name        = "${var.prefix}-worker"
  description = "worker nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}", "${aws_subnet.controlplane.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = false
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.controlplane.cidr_block}"]
    self        = false
  }

  egress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["${aws_subnet.etcd.cidr_block}", "${aws_subnet.controlplane.cidr_block}", "${aws_subnet.worker.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data_server" {
  template = "${file("files/userdata_server")}"

  vars {
    docker_version_server = "${var.docker_version_server}"
    rancher_version       = "${var.rancher_version}"
  }
}

data "template_file" "user_data_agent" {
  template = "${file("files/userdata_agent")}"

  vars {
    docker_version_agent = "${var.docker_version_agent}"
    rancher_version      = "${var.rancher_version}"
  }
}

resource "aws_instance" "rancher-server" {
  count                       = "1"
  ami                         = "${data.aws_ami.ubuntuxenial.id}"
  instance_type               = "${var.instance_size}"
  subnet_id                   = "${aws_subnet.rancher.id}"
  associate_public_ip_address = "true"
  key_name                    = "${var.key_name}"
  user_data                   = "${data.template_file.user_data_server.rendered}"
  vpc_security_group_ids      = ["${aws_security_group.rancher.id}"]

  tags {
    Name = "${var.prefix}-rancher-server"
  }
}

resource "aws_instance" "rancher-agent-etcd" {
  count                       = "${var.count_etcd_nodes}"
  ami                         = "${data.aws_ami.ubuntuxenial.id}"
  instance_type               = "${var.instance_size}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.etcd.id}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.etcd.id}"]
  user_data                   = "${data.template_file.user_data_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancher-agent-etcd-${count.index}"
  }
}

resource "aws_instance" "rancher-agent-controlplane" {
  count                       = "${var.count_controlplane_nodes}"
  ami                         = "${data.aws_ami.ubuntuxenial.id}"
  instance_type               = "${var.instance_size}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.controlplane.id}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.controlplane.id}"]
  user_data                   = "${data.template_file.user_data_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancher-agent-controlplane-${count.index}"
  }
}

resource "aws_instance" "rancher-agent-worker" {
  count                       = "${var.count_worker_nodes}"
  ami                         = "${data.aws_ami.ubuntuxenial.id}"
  instance_type               = "${var.instance_size}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.worker.id}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.worker.id}"]
  user_data                   = "${data.template_file.user_data_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancher-agent-worker-${count.index}"
  }
}

output "rancher-url" {
  value = ["https://${aws_instance.rancher-server.public_ip}"]
}

output "rancher-etcd-nodes" {
  value = ["${aws_instance.rancher-agent-etcd.*.public_ip}"]
}

output "rancher-controlplane-nodes" {
  value = ["${aws_instance.rancher-agent-controlplane.*.public_ip}"]
}

output "rancher-worker-nodes" {
  value = ["${aws_instance.rancher-agent-worker.*.public_ip}"]
}
