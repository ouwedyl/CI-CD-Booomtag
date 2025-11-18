# terraform commands.
# terraform init
# terraform apply -auto-approve
# terraform destroy -auto-approve

# RDS database manual access: mysqlsh -h <endpoint> -u test -p
# Destroy the cache of the zip: terraform destroy -target aws_s3_bucket.octobercms_bucket -auto-approve

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

variable "aws_region" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "mysql_root_password" {}
variable "mysql_database" {}
variable "mysql_user" {}
variable "mysql_password" {}
data "aws_caller_identity" "current" {}


# Create the VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "my_vpc"
  }
}

# Create cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "Robert_cluster"
}

# Public Subnet (for web app)
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"  # Subnet range within the VPC
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1a"  # Use a specific AZ or make this dynamic
  tags = {
    Name = "public_subnet"
  }
}

# Private Subnet (for database)
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-central-1a"
  tags = {
    Name = "private_subnet"
  }
}

# Private Subnet 2 (for database) - new subnet in a different AZ
resource "aws_subnet" "private_subnet_2" {
  vpc_id                   = aws_vpc.my_vpc.id
  cidr_block               = "10.0.3.0/24"  # Make sure this range doesn't overlap
  map_public_ip_on_launch  = false
  availability_zone        = "eu-central-1b"  # Different Availability Zone
  tags = {
    Name = "private_subnet_2"
  }
}


# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_igw"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "public_route_table"
  }
}

# Route to the Internet Gateway
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id

  lifecycle {
    ignore_changes = [
      destination_cidr_block,
      gateway_id
    ]
  }
}

# Associate the Public Subnet with the Public Route Table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the private subnets with the public route table (to allow internet access)
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}


# Create a security group dynamically
resource "aws_security_group" "web_app_sg" {
  vpc_id = aws_vpc.my_vpc.id
  name   = "web_app_sg"
  description = "Security group for web app allowing HTTP traffic"

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

  tags = {
    Name = "web_app_sg"
  }
}

resource "aws_security_group" "database_sg" {
  vpc_id = aws_vpc.my_vpc.id
  name   = "database_sg"
  description = "Security group for MySQL database"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database_sg"
  }
}

# ECS Web App Task Definition
resource "aws_ecs_task_definition" "web_app" {
  family                   = "web-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-app-container"
      image     = "octobercms/october-dev"
      portMappings = [{
        containerPort = 80
        hostPort      = 80
      }]
      environment = [
        # Pass S3 Bucket details
        { name = "AWS_S3_BUCKET", value = aws_s3_bucket.octobercms_bucket.bucket },
        { name = "AWS_S3_KEY", value = aws_s3_object.octobercms_files.key },

        # Pass RDS database connection details
        { name = "DB_HOST", value = aws_db_instance.my_database.address },
        { name = "DB_DATABASE", value = var.mysql_database },
        { name = "DB_USERNAME", value = var.mysql_user },
        { name = "DB_PASSWORD", value = var.mysql_password }
      ]
      logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "R_multiContainer"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "container-1"
      }
    }
      # Override with a custom octobercsm implementation.
      command = [
        "sh", "-c", "apt-get update; apt-get install -y unzip awscli; mkdir -p /var/www/html; aws s3 cp s3://${aws_s3_bucket.octobercms_bucket.bucket}/${aws_s3_object.octobercms_files.key} /var/www/html/octobercms.zip; unzip /var/www/html/octobercms.zip -d /var/www/html; mv /var/www/html/octobercms/index.php /var/www/html/; ls -l /var/www/html; chown -R www-data:www-data /var/www/html; apache2-foreground"
      ]
      
    }
  ])
}


# ECS Database Task Definition
resource "aws_ecs_task_definition" "database" {
  family                   = "database"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "512"
  cpu                      = "256"
  
  container_definitions = jsonencode([{
      name      = "database-container"
      image     = "mysql:latest"
      portMappings = [{
          containerPort = 3306
          hostPort      = 3306
      }]
      environment = [
        { name  = "MYSQL_ROOT_PASSWORD", value = var.mysql_root_password },
        { name  = "MYSQL_DATABASE", value = var.mysql_database },
        { name  = "MYSQL_USER", value = var.mysql_user },
        { name  = "MYSQL_PASSWORD", value = var.mysql_password }
      ]
  }])
}

# ECS Web App Service
resource "aws_ecs_service" "web_app_service" {
  name            = "web-app-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.web_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  enable_execute_command = true

  network_configuration {
    subnets         = [aws_subnet.public_subnet.id]
    security_groups = [aws_security_group.web_app_sg.id]  # Use the dynamically created security group
    assign_public_ip = true
  }
}

# Create the DB subnet group for RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
    subnet_ids = [
      aws_subnet.public_subnet.id,
      aws_subnet.private_subnet.id,  # First private subnet (eu-central-1a)
      aws_subnet.private_subnet_2.id   # Second private subnet (eu-central-1b)
  ]

  tags = {
    Name = "my-db-subnet-group"
  }
}

# Create the RDS MySQL instance
resource "aws_db_instance" "my_database" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"  # Use the desired MySQL version
  instance_class       = "db.t3.micro"  # Choose an instance type
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  username             = var.mysql_user
  password             = var.mysql_password
  db_name              = var.mysql_database
  skip_final_snapshot  = true  # Set to false in production for a backup before deletion

  # Optional - Enable automated backups and other parameters
  backup_retention_period = 7  # Retain backups for 7 days
  multi_az               = false  # Set to true for high availability

  # Security settings
  vpc_security_group_ids = [aws_security_group.database_sg.id]  # Allow access from your ECS tasks
  publicly_accessible = true
}

# Fetch the RDS instance details to get the endpoint
data "aws_db_instance" "my_database" {
  db_instance_identifier = aws_db_instance.my_database.id
}

# Provisioning the SQL script to be executed
resource "null_resource" "init_sql" {
  depends_on = [aws_db_instance.my_database]

  provisioner "local-exec" {
    command = "type ${path.module}\\sql_fate_data.sql | docker run --rm -i mysql:8 mysql -h ${aws_db_instance.my_database.address} -u ${var.mysql_user} -p${var.mysql_password} ${var.mysql_database}"
  }
}

resource "null_resource" "bundle_octobercms" {
  provisioner "local-exec" {
    # Command to zip the octobercms.zip; Ensure it does not already exist.  
    command = "powershell Remove-Item -Path .\\octobercms.zip -ErrorAction SilentlyContinue; Compress-Archive -Path .\\octobercms\\* -DestinationPath .\\octobercms.zip"
  }

triggers = {
    always_run = timestamp()  # This ensures a new value on every apply
  }
}


resource "aws_s3_bucket" "octobercms_bucket" {
  bucket = "octobercms-files-67n4mpxup" # Ensure all lowercase
  force_destroy = true
}

resource "aws_s3_object" "octobercms_files" {
  acl                    = "private"
  bucket                 = "octobercms-files-67n4mpxup"
  key                    = "octobercms-${random_string.s3_key_suffix.result}.zip"
  source                 = "./octobercms.zip"
  depends_on             = [null_resource.bundle_octobercms] # Ensure file creation is done
}

resource "random_string" "s3_key_suffix" {
  length  = 8
  special = false
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "ecs-task-role"
  }
}

# Attach the necessary policies to the IAM role
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 permissions
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::octobercms-files-67n4mpxup",
          "arn:aws:s3:::octobercms-files-67n4mpxup/*"
        ]
      },
      # CloudWatch Logs permissions
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:205930632714:log-group:R_multiContainer:*"      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}