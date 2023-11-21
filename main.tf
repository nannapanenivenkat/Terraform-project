resource "aws_vpc" "myvpc" {
  cidr_block       = var.cidr
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "sub1" {
    vpc_id                  = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = "true"
  
}

resource "aws_subnet" "sub2" {
    vpc_id                  = aws_vpc.myvpc.id
    cidr_block = "10.0.10.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = "true"
  
}

resource "aws_internet_gateway" "igw" {
  vpc_id                  = aws_vpc.myvpc.id
}

resource "aws_route_table" "route" {
    vpc_id = aws_vpc.myvpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id             = aws_internet_gateway.igw.id
    }
  
}

resource "aws_route_table_association" "routeass" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.route.id
  
}

resource "aws_route_table_association" "routeass2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.route.id
  
}

resource "aws_security_group" "mysec" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

    ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  tags = {
    Name = "allow_tls"
  }
}


#creating bucket and assigning public access
resource "aws_s3_bucket" "example" {
  bucket = "my-tf-test-bucket"

}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.example.id
  acl    = "public-read"
}


#creating ec2 instance
resource "aws_ec2_instance" "webserver1" {
  ami                     = "ami-0dcc1e21636832c5d"
  instance_type           = var.instance_type
  vpc_security_group_ids  = [aws_security_group.mysec.id]
  key_name                = var.key_pair
  associate_public_ip_address = true
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userdata.sh"))

}

resource "aws_ec2_instance" "webserver2" {
  ami                     = "ami-0dcc1e21636832c5d"
  instance_type           = var.instance_type
  vpc_security_group_ids  = [aws_security_group.mysec.id]
  key_name                = var.key_pair
  associate_public_ip_address = true
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userdata1.sh"))

}

#creating load balancer
resource "aws_lb" "lbtest" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mysec.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]


  tags = {
    name = "test-lb-tf"
    Environment = "production"
  }
}

#creating target group
resource "aws_lb_target_group" "tgtest" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path      = "/"
    port = "traffic-port"

  }
}

resource "aws_alb_target_group_attachment" "attach1" {
    target_group_arn  = aws_lb_target_group.tgtest.arn
    target_id         = aws_ec2_instance.webserver1.id
    port              = 80

  
}

resource "aws_alb_target_group_attachment" "attach2" {
    target_group_arn  = aws_lb_target_group.tgtest.arn
    target_id         = aws_ec2_instance.webserver1.id
    port              = 80

  
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lbtest.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgtest.arn
  }
}

output "loadbalancerdns" {
    value = "${aws_lb.lbtest.dns_name}"
  
}