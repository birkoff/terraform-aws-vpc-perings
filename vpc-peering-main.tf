# Omit if vpc is in same account
data "aws_vpc" "peer-main" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.main"
  id       = "${lookup(local.vpc_peering_ids, "main")}"
}

data "aws_caller_identity" "peer-main" {
  # Note: the provider cannot be passed as a variable
  provider = "aws.main"
}

data "aws_route_tables" "peer-main" {
  provider = "aws.main"
  vpc_id   = "${data.aws_vpc.peer-main.id}"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "requester-to-main" {
  # Note: the provider cannot be passed as a variable
  vpc_id        = "${data.aws_vpc.local.id}"
  peer_vpc_id   = "${data.aws_vpc.peer-main.id}"
  peer_owner_id = "${data.aws_caller_identity.peer-main.account_id}"
  peer_region   = "${lookup(local.vpc_regions, var.region_name)}"
  auto_accept   = false

  tags = {
    Name  = "${format("%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-main.tags.Name)}"
    Local = "${data.aws_vpc.local.tags.Name}"
    Peer  = "${data.aws_vpc.peer-main.tags.Name}"
    Side  = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "accepter-main" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.main"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-main.id}"
  auto_accept               = true

  tags = {
    Name  = "${format("%s-peering-%s", data.aws_vpc.local.tags.Name, data.aws_vpc.peer-main.tags.Name)}"
    Local = "${data.aws_vpc.peer-main.tags.Name}"
    Peer  = "${data.aws_vpc.local.tags.Name}"
    Side  = "Accepter"
  }
}

resource "aws_route" "local-to-main" {
  # Note: the provider cannot be passed as a variable
  count                     = "${length(data.aws_route_tables.local.ids)}"
  destination_cidr_block    = "${data.aws_vpc.peer-main.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-main.id}"
//  route_table_id            = "${data.aws_route_tables.local.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.local.ids)[count.index]}"

}

resource "aws_route" "main-to-local" {
  # Note: the provider cannot be passed as a variable
  provider                  = "aws.main"
  count                     = "${length(data.aws_route_tables.peer-main.ids)}"
  destination_cidr_block    = "${data.aws_vpc.local.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester-to-main.id}"
//  route_table_id            = "${data.aws_route_tables.peer-main.ids[count.index]}"
  route_table_id            = "${tolist(data.aws_route_tables.peer-main.ids)[count.index]}"
}
