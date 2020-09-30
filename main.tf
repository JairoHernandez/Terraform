provider "aws" {
    region = "us-east-2"
}

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}

output "public" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}

########### ASG ###########
# Similar parameters in resource "aws_instance"
# ami = image_id, vpc_security_group_ids = security_groups
resource "aws_launch_configuration" "example" {
    # image_id = "ami-0c55b159cbfafe1f0" # the damn image!!!
    image_id = "ami-07efac79022b86107"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]

    user_data = <<-EOF
        #!/bin/bash
        echo "Hello, world" > index.html
        nohup busybox httpd -f -p ${var.server_port} &
        EOF
    
    # Required when using launch configuration with an auto scaling group.
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "example" {
    launch_configuration = aws_launch_configuration.example.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids # All subnets in default VPC

    # Tell target group which EC2 instance to send requests to. Added after creating resource aws_lb_target_group.
    target_group_arns = [aws_lb_target_group.asg.arn] # arn = amazon reource name
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraforma-asg-example"
        propagate_at_launch = true
    }
}

data "aws_vpc" "default" {
    default = true # looks up default VPC in your AWS account
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id # looks up all subnets within VPC
}

# Did not change from previous lesson.
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

########### APPLICATION LOAD BALANCER(ALB) ###########
resource "aws_lb" "example" { # load balancer itself
    name = "terraform-asg-example"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" { # define listner for ALB
    load_balancer_arn = aws_lb.example.arn # arn = Amazon Resource Name
    port = 80
    protocol = "HTTP"

    # By default, return a simple 404
    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = 404
        }
    }
}

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"
    
    # Allow inbound HTTP requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow outbound HTTP requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # All
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200" # expects EC2 instance to return 200 OK during health check
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

# Create listener rules.
# Requests sent to target group matching any path.
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
        path_pattern {
            values = ["*"] # match any path to the target group that contains your ASG
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}