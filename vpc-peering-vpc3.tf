provider "aws" {
  alias  = "account3"

  region = "${lookup(local.vpc_regions, var.region_name)}"

  assume_role {
    role_arn = "arn:aws:iam::${lookup(local.account_ids, "account3")}:role/${var.assume_role}"
  }
}

data "aws_vpc" "peer-vpc3" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account3"
  id       = "${lookup(local.vpc_peering_ids, "vpc3")}"
}

data "aws_caller_identity" "peer-vpc3" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.account3"
}


data "aws_route_tables" "peer-vpc3" {
  provider = "aws.account3"
  vpc_id   = "${data.aws_vpc.peer-vpc3.id}"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "requester-to-vpc3" {
  # Note: the provider cannot be passed as a variable
  vpc_id        = "${data.aws_vpc.local.id}"
  peer_vpc_id   = "${data.aws_vpc.peer-vpc3.id}"
  peer_owner_id = "${data.aws_caller_identity.peer-vpc3.account_id}"
  peer_region   = "${lookup(local.vpc_regions, var.region_name)}"
  auto_accept   = false

  tags = {
    Name  = "${format("vpc-%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc3.tags.Name)}"
    Local = "${data.aws_vpc.local.tags.Name}"
    Peer  = "${data.aws_vpc.peer-vpc3.tags.Name}"
    Side  = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "accepter-vpc3" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account3"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc3.id}"
  auto_accept               = true

  tags = {
    Name  = "${format("vpc-%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-vpc3.tags.Name)}"
    Local = "${data.aws_vpc.peer-vpc3.tags.Name}"
    Peer  = "${data.aws_vpc.local.tags.Name}"
    Side  = "Accepter"
  }
}

resource "aws_route" "local-to-vpc3" {
  # Note: the provider cannot be passed as a variable
  count                     = "${length(data.aws_route_tables.local.ids)}"
  destination_cidr_block    = "${data.aws_vpc.peer-vpc3.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc3.id}"
//  route_table_id            = "${data.aws_route_tables.local.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.local.ids)[count.index]}"
}

resource "aws_route" "vpc3-to-local" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.account3"
  count                     = "${length(data.aws_route_tables.peer-vpc3.ids)}"
  destination_cidr_block    = "${data.aws_vpc.local.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-vpc3.id}"
//  route_table_id            = "${data.aws_route_tables.peer-vpc3.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.peer-vpc3.ids)[count.index]}"
}
