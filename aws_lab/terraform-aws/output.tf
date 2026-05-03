output "ec2_ip" {
  value = aws_instance.route.public_ip
}
output "vpc_id" {
  value = aws_vpc.route_vpc.id
}
output "nat_gw_id" {
  value = aws_nat_gateway.route_nat_gw.id
}

output "availability_zone" {
  value =  data.aws_availability_zones.available.names[0]
}