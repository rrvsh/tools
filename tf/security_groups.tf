resource "aws_security_group" "http_ingress" {
  description = "Allows HTTP and HTTPS inbound traffic and all outbound traffic."
  name        = "http_ingress"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows HTTP inbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows HTTPS inbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows all outbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
