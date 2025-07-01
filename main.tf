# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "app-gateway-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "app-gateway-igw"
  }
}

# Create first public subnet for ALB
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

# Create second public subnet for ALB
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# Create private subnet for VM
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone_1

  tags = {
    Name = "private-subnet"
  }
}

# Create route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate first public subnet with route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate second public subnet with route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "nat-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "app-gateway-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Create route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Associate private subnet with route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Create security group for ALB
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "alb-sg"
  }
}

# Create security group for VM
resource "aws_security_group" "vm" {
  name        = "vm-sg"
  description = "Security group for VM"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "vm-sg"
  }
}

# Create key pair for SSH access
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)  # Make sure this key exists
}

# Create AWS VM
resource "aws_instance" "vm" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.vm.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
              #!/bin/bash
              
              # Log everything to a file for debugging
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting user data script at $(date)"
              
              # Wait for cloud-init to complete
              cloud-init status --wait
              
              # Update system and install packages
              echo "Installing packages..."
              yum update -y
              yum install -y httpd curl wget unzip
              
              # Start and enable Apache
              echo "Starting Apache..."
              systemctl start httpd
              systemctl enable httpd
              
              # Create a comprehensive status page
              cat > /var/www/html/index.html << 'HTML_EOF'
              <!DOCTYPE html>
              <html lang="en">
              <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Application Gateway Test Page</title>
                  <style>
                      body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
                      .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                      .header { text-align: center; color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 20px; margin-bottom: 30px; }
                      .status { background: #e8f5e8; border: 1px solid #4caf50; padding: 15px; border-radius: 5px; margin: 20px 0; }
                      .info { background: #e3f2fd; border: 1px solid #2196f3; padding: 15px; border-radius: 5px; margin: 20px 0; }
                      .section { margin: 20px 0; }
                      .section h3 { color: #2c3e50; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }
                      code { background: #f8f9fa; padding: 2px 5px; border-radius: 3px; font-family: monospace; }
                      .timestamp { color: #7f8c8d; font-size: 0.9em; }
                  </style>
              </head>
              <body>
                  <div class="container">
                      <div class="header">
                          <h1>🚀 Application Gateway Test Page</h1>
                          <p>Your infrastructure is working correctly!</p>
                      </div>
                      
                      <div class="status">
                          <h3>✅ Status: Online</h3>
                          <p>This page confirms that your Application Load Balancer is successfully routing traffic to your EC2 instance.</p>
                      </div>
                      
                      <div class="section">
                          <h3>📊 System Information</h3>
                          <div class="info">
                              <p><strong>Instance ID:</strong> <code>$(curl -s http://169.254.169.254/latest/meta-data/instance-id)</code></p>
                              <p><strong>Instance Type:</strong> <code>$(curl -s http://169.254.169.254/latest/meta-data/instance-type)</code></p>
                              <p><strong>Availability Zone:</strong> <code>$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</code></p>
                              <p><strong>Private IP:</strong> <code>$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</code></p>
                              <p><strong>Public IP:</strong> <code>$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)</code></p>
                          </div>
                      </div>
                      
                      <div class="section">
                          <h3>🌐 Network Information</h3>
                          <div class="info">
                              <p><strong>Hostname:</strong> <code>$(hostname)</code></p>
                              <p><strong>Apache Version:</strong> <code>$(httpd -v | head -1)</code></p>
                              <p><strong>Server Time:</strong> <code>$(date)</code></p>
                          </div>
                      </div>
                      
                      <div class="section">
                          <h3>🔧 Health Check Endpoints</h3>
                          <div class="info">
                              <p><strong>Main Page:</strong> <code>/</code> (this page)</p>
                              <p><strong>Health Check:</strong> <code>/health</code></p>
                              <p><strong>Status:</strong> <code>/status</code></p>
                          </div>
                      </div>
                      
                      <div class="section">
                          <h3>📝 Architecture Overview</h3>
                          <div class="info">
                              <p>This setup demonstrates:</p>
                              <ul>
                                  <li>✅ Application Load Balancer (ALB) in public subnets</li>
                                  <li>✅ EC2 instance in private subnet for security</li>
                                  <li>✅ Proper security group configuration</li>
                                  <li>✅ Health checks and target group routing</li>
                                  <li>✅ Multi-AZ deployment for high availability</li>
                              </ul>
                          </div>
                      </div>
                      
                      <div class="timestamp">
                          <p>Page generated on: <code>$(date)</code></p>
                      </div>
                  </div>
              </body>
              </html>
              HTML_EOF
              
              # Create health check endpoint
              cat > /var/www/html/health << 'HEALTH_EOF'
              {
                "status": "healthy",
                "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
                "availability_zone": "$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)",
                "service": "apache",
                "version": "$(httpd -v | head -1 | cut -d' ' -f3 | cut -d'/' -f2)"
              }
              HEALTH_EOF
              
              # Create status endpoint
              cat > /var/www/html/status << 'STATUS_EOF'
              <!DOCTYPE html>
              <html>
              <head><title>Server Status</title></head>
              <body>
                  <h2>Server Status</h2>
                  <p><strong>Apache Status:</strong> $(systemctl is-active httpd)</p>
                  <p><strong>Uptime:</strong> $(uptime)</p>
                  <p><strong>Load Average:</strong> $(uptime | awk -F'load average:' '{print $2}')</p>
                  <p><strong>Memory Usage:</strong> $(free -h | grep Mem | awk '{print $3"/"$2}')</p>
                  <p><strong>Disk Usage:</strong> $(df -h / | tail -1 | awk '{print $5}')</p>
                  <p><strong>Last Updated:</strong> $(date)</p>
              </body>
              </html>
              STATUS_EOF
              
              # Set proper permissions
              chown apache:apache /var/www/html/*
              chmod 644 /var/www/html/*
              
              # Create a simple test script for debugging
              cat > /home/ec2-user/test-connection.sh << 'SCRIPT_EOF'
              #!/bin/bash
              echo "=== Connection Test Script ==="
              echo "Testing local Apache connection..."
              curl -s -o /dev/null -w "HTTP Status: %%{http_code}\n" http://localhost/
              echo "Testing metadata service..."
              curl -s http://169.254.169.254/latest/meta-data/instance-id
              echo ""
              echo "=== System Information ==="
              echo "Hostname: $(hostname)"
              echo "IP Address: $(hostname -I)"
              echo "Apache Status: $(systemctl is-active httpd)"
              echo "=== End Test ==="
              SCRIPT_EOF
              
              chmod +x /home/ec2-user/test-connection.sh
              
              # Log the setup completion
              echo "Web server setup completed at $(date)" >> /var/log/web-setup.log
              
              # Test Apache is working
              echo "Testing Apache..."
              curl -s http://localhost/ > /dev/null && echo "Apache test successful" || echo "Apache test failed"
              
              echo "User data script completed at $(date)"
              EOF

  tags = {
    Name = "terraform-vm"
  }
}

# Create Application Load Balancer (AWS equivalent of Application Gateway)
resource "aws_lb" "main" {
  name               = "app-gateway-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "app-gateway-alb"
  }
}

# Create ALB target group
resource "aws_lb_target_group" "main" {
  name     = "app-gateway-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Attach VM to target group
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.vm.id
  port             = 80
}

# Create ALB listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Output the ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The DNS name of the Application Load Balancer"
}

# Output the VM private IP
output "vm_private_ip" {
  value       = aws_instance.vm.private_ip
  description = "The private IP address of the VM"
}

# Output health check URL
output "health_check_url" {
  value       = "http://${aws_lb.main.dns_name}/health"
  description = "URL to check the health status of the application"
}

# Output status page URL
output "status_page_url" {
  value       = "http://${aws_lb.main.dns_name}/status"
  description = "URL to view the server status page"
}
