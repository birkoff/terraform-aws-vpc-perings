data "aws_vpc" "local" {
  id = "${data.terraform_remote_state.network.outputs.vpc_id}"
}

data "aws_route_tables" "local" {
  vpc_id = "${data.aws_vpc.local.id}"
}
