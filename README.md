Hi,
This terraform code has all necessary resources for a 3-tier architecture are created and managed by Terraform, with state stored securely in an S3 bucket and state locking managed by a DynamoDB table.
Below is the explanation of every terraform code block : 

**Provider Configuration**
provider "aws" {
  region = "eu-west-2"
}

**This block specifies that we are using AWS as our cloud provider and sets the region to eu-west-2.**

**Backend Configuration**
terraform {
  backend "s3" {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "path/to/my/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}

**This block configures Terraform to use an S3 bucket for storing the state file and a DynamoDB table for state locking. This ensures that the state is stored securely and that only one operation can modify the state at a time.**

**S3 Bucket for Terraform State**
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

**This block creates an S3 bucket named my-terraform-state-bucket with private access. It enables versioning to keep track of changes to the state file and configures server-side encryption using AES-256 for security.**

**DynamoDB Table for State Locking**
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

**This block creates a DynamoDB table named terraform-lock-table with a primary key LockID. The table is used to manage state locks, ensuring that only one Terraform operation can run at a time.**

**VPC Configuration**
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

**This block creates a Virtual Private Cloud (VPC) with a CIDR block of 10.0.0.0/16. A VPC is a virtual network dedicated to your AWS account.**

**Subnets**
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

**These blocks create two subnets within the VPC: a public subnet (10.0.1.0/24) that assigns public IPs to instances and a private subnet (10.0.2.0/24) that does not.**

**Internet Gateway**
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

**This block creates an Internet Gateway and attaches it to the VPC, allowing instances in the public subnet to access the internet.**

**Route Table**
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

**These blocks create a route table for the public subnet, directing all traffic (0.0.0.0/0) to the Internet Gateway, and associate the route table with the public subnet.**

**Security Groups**
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

**These blocks create security groups for the web, application, and database tiers. Each security group defines ingress and egress rules to control traffic flow:**

Web Security Group: Allows HTTP traffic (port 80) from anywhere.
App Security Group: Allows traffic on port 8080 from the public subnet.
DB Security Group: Allows MySQL traffic (port 3306) from the private subnet.

**EC2 Instances**
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.web_sg.name]

  tags = {
    Name = "WebServer"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.app_sg.name]

  tags = {
    Name = "AppServer"
  }
}

**These blocks create EC2 instances for the web and application tiers. Each instance is assigned to the appropriate subnet and security group:**

Web Instance: Uses the public subnet and web security group.
App Instance: Uses the private subnet and app security group.
**RDS Instance**
resource "aws_db_instance" "db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
}

**This block creates an RDS instance for the database tier. It specifies the storage, engine type (MySQL), version, instance class, and security group. The database is placed in the private subnet.**

**DB Subnet Group**
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.private.id]

  tags = {
    Name = "MainSubnetGroup"
  }
}

**This block creates a DB subnet group, which is required for the RDS instance to specify which subnets it can use.**

**Outputs**
output "web_instance_id" {
  value = aws_instance.web.id
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "db_instance_endpoint" {
  value = aws_db_instance.db.endpoint
}

**These blocks define outputs that will be displayed after Terraform applies the configuration. They include the IDs of the web and app instances and the endpoint of the RDS instance.**


Initialize Terraform: Run **terraform init** to initialize your configuration.

Plan: Run **terraform plan** to see what changes will be made.

Apply: Run **terraform apply** to create the resources.
