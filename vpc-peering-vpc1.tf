provider "aws" {
  alias  = "account1"
  region = "${lookup(local.vpc_regions, var.region_name)}"

  assume_role {
    role_arn = "arn:aws:iam::${lookup(local.account_ids, "account1")}:role/${var.assume_role}"
  }
}

data "aws_vpc" "peer-vpc1" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account1"
  id       = "${lookup(local.vpc_peering_ids, "vpc1")}"
}

data "aws_caller_identity" "peer-vpc1" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account1"
}

data "aws_route_tables" "peer-vpc1" {
  provider = "aws.account1"
  vpc_id   = "${data.aws_vpc.peer-vpc1.id}"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "requester-to-vpc1" {
  # Note: the provider cannot be passed as a variable
  vpc_id        = "${data.aws_vpc.local.id}"
  peer_vpc_id   = "${data.aws_vpc.peer-vpc1.id}"
  peer_owner_id = "${data.aws_caller_identity.peer-vpc1.account_id}"
  peer_region   = "${lookup(local.vpc_regions, var.region_name)}"
  auto_accept   = false

  tags = {
    Name  = "${format("%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc1.tags.Name)}"
    Local = "${data.aws_vpc.local.tags.Name}"
    Peer  = "${data.aws_vpc.peer-vpc1.tags.Name}"
    Side  = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "accepter-vpc1" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account1"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc1.id}"
  auto_accept               = true

  tags = {
    Name  = "${format("%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc1.tags.Name)}"
    Local = "${data.aws_vpc.peer-vpc1.tags.Name}"
    Peer  = "${data.aws_vpc.local.tags.Name}"
    Side  = "Accepter"
  }
}

resource "aws_route" "local-to-vpc1" {
  # Note: the provider cannot be passed as a variable
  count                     = "${length(data.aws_route_tables.local.ids)}"
  destination_cidr_block    = "${data.aws_vpc.peer-vpc1.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc1.id}"
//  route_table_id            = "${data.aws_route_tables.local.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.local.ids)[count.index]}"
}

resource "aws_route" "vpc1-to-local" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account1"
  count                     = "${length(data.aws_route_tables.peer-vpc1.ids)}"
  destination_cidr_block    = "${data.aws_vpc.local.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc1.id}"
//  route_table_id            = "${data.aws_route_tables.peer-vpc1.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.peer-vpc1.ids)[count.index]}"
}
