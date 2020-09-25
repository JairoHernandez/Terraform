provider "aws" {
    region = "us-east-2"
}

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}

output "public" {
    value = aws_instance.example.public_ip
    description = "The public IP address of the web server"
}

resource "aws_instance" "example" {
    ami = "ami-07efac79022b86107"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id] # reference, mores specifically resource attribute reference

    user_data = <<-EOF
        #!/bin/bash
        echo "Hello, world" > index.html
        nohup busybox httpd -f -p ${var.server_port} &
        EOF

    tags = {
        Name = "terraform-example"
    }

}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}