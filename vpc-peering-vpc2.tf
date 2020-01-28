provider "aws" {
  alias  = "account2"

  region = "${lookup(local.vpc_regions, var.region_name)}"

  assume_role {
    role_arn = "arn:aws:iam::${lookup(local.account_ids, "account2")}:role/${var.assume_role}"
  }
}

data "aws_vpc" "peer-vpc2" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account2"
  id       = "${lookup(local.vpc_peering_ids, "vpc2")}"
}

data "aws_caller_identity" "peer-vpc2" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account2"
}


data "aws_route_tables" "peer-vpc2" {
  provider = "aws.account2"
  vpc_id   = "${data.aws_vpc.peer-vpc2.id}"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "requester-to-vpc2" {
  # Note: the provider cannot be passed as a variable
  vpc_id        = "${data.aws_vpc.local.id}"
  peer_vpc_id   = "${data.aws_vpc.peer-vpc2.id}"
  peer_owner_id = "${data.aws_caller_identity.peer-vpc2.account_id}"
  peer_region   = "${lookup(local.vpc_regions, var.region_name)}"
  auto_accept   = false

  tags = {
    Name  = "${format("vpc-%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc2.tags.Name)}"
    Local = "${data.aws_vpc.local.tags.Name}"
    Peer  = "${data.aws_vpc.peer-vpc2.tags.Name}"
    Side  = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "accepter-vpc2" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account2"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc2.id}"
  auto_accept               = true

  tags = {
    Name  = "${format("vpc-%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc2.tags.Name)}"
    Local = "${data.aws_vpc.peer-vpc2.tags.Name}"
    Peer  = "${data.aws_vpc.local.tags.Name}"
    Side  = "Accepter"
  }
}

resource "aws_route" "local-to-vpc2" {
  # Note: the provider cannot be passed as a variable
  count                     = "${length(data.aws_route_tables.local.ids)}"
  destination_cidr_block    = "${data.aws_vpc.peer-vpc2.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc2.id}"
//  route_table_id            = "${data.aws_route_tables.local.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.local.ids)[count.index]}"
}

resource "aws_route" "vpc2-to-local" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account2"
  count                     = "${length(data.aws_route_tables.peer-vpc2.ids)}"
  destination_cidr_block    = "${data.aws_vpc.local.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc2.id}"
//  route_table_id            = "${data.aws_route_tables.peer-vpc2.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.peer-vpc2.ids)[count.index]}"
}
