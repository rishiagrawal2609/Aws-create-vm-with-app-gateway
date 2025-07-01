# AWS Application Gateway with VM

This Terraform configuration creates a production-ready infrastructure with an Application Load Balancer (AWS equivalent of Application Gateway) and attaches it to a VM in a private subnet with proper networking, security, and monitoring.

## 🏗️ Architecture Overview

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                │
│                     (Public Subnets)                       │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   Public Subnet │  │   Public Subnet │                  │
│  │   (us-east-1a)  │  │   (us-east-1b)  │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Group                             │
│              (Health Checks & Routing)                     │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    NAT Gateway                              │
│                   (Public Subnet)                          │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    EC2 Instance                             │
│                  (Private Subnet)                          │
│              ┌─────────────────────────┐                   │
│              │     Apache Web Server   │                   │
│              │   (Port 80/443)         │                   │
│              └─────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Infrastructure Components

### Networking
- **VPC**: Custom VPC with CIDR `10.0.0.0/16`
- **Public Subnets**: Two subnets across different AZs for ALB high availability
- **Private Subnet**: One subnet for the EC2 instance (security)
- **Internet Gateway**: Provides internet access to public subnets
- **NAT Gateway**: Allows private subnet instances to access internet
- **Route Tables**: Proper routing between public and private subnets

### Compute
- **EC2 Instance**: Amazon Linux 2 instance in private subnet
- **Web Server**: Apache HTTP Server with comprehensive status pages
- **User Data**: Automated installation and configuration script

### Load Balancing
- **Application Load Balancer**: Layer 7 load balancer in public subnets
- **Target Group**: Routes traffic to EC2 instance with health checks
- **Listener**: HTTP listener on port 80
- **Health Checks**: Automatic health monitoring and failover

### Security
- **Security Groups**: Restrictive firewall rules
  - ALB: Allows HTTP/HTTPS from internet
  - EC2: Allows HTTP/HTTPS from ALB, SSH from internet
- **Private Subnet**: EC2 instance isolated from direct internet access
- **SSH Key Pair**: Secure access to EC2 instance

### Monitoring & Debugging
- **Health Check Endpoints**: `/health` (JSON) and `/status` (HTML)
- **Comprehensive Status Page**: Real-time system information
- **Logging**: User data script logs for troubleshooting
- **Test Scripts**: Built-in connection testing tools

## 📋 Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (version >= 1.0)
3. **AWS Permissions** - IAM user/role with permissions for:
   - VPC, EC2, ELB, IAM, EIP, NAT Gateway

## 🛠️ Quick Start

### 1. Clone and Navigate
```bash
cd Aws-create-vm-app-gateway
```

### 2. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferred values
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan Deployment
```bash
terraform plan
```

### 5. Deploy Infrastructure
```bash
terraform apply
```

### 6. Access Your Application
```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Test the application
curl http://$(terraform output -raw alb_dns_name)/
```

## 🔧 Configuration Options

### Network Configuration
```hcl
# VPC and Subnet CIDRs
vpc_cidr              = "10.0.0.0/16"
public_subnet_1_cidr  = "10.0.1.0/24"
public_subnet_2_cidr  = "10.0.2.0/24"
private_subnet_cidr   = "10.0.3.0/24"

# Availability Zones
availability_zone_1   = "us-east-1a"
availability_zone_2   = "us-east-1b"
```

### EC2 Configuration
```hcl
# Instance specifications
instance_type = "t2.micro"
ami_id        = "ami-05ffe3c48a9991133"  # Amazon Linux 2
```

### Load Balancer Configuration
```hcl
# ALB settings
alb_name           = "app-gateway-alb"
target_group_name  = "app-gateway-tg"
health_check_path  = "/"
health_check_port  = "80"
```

## 📊 Monitoring & Health Checks

### Health Check Endpoints
- **Main Page**: `http://<alb-dns-name>/` - Comprehensive status page
- **Health Check**: `http://<alb-dns-name>/health` - JSON health status
- **Server Status**: `http://<alb-dns-name>/status` - System metrics

### Health Check Response Example
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "instance_id": "i-1234567890abcdef0",
  "availability_zone": "us-east-1a",
  "service": "apache",
  "version": "2.4.54"
}
```

### ALB Health Check Configuration
- **Protocol**: HTTP
- **Port**: 80
- **Path**: `/`
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 2

## 🔍 Troubleshooting

### Common Issues

#### 1. 502 Bad Gateway Error
**Symptoms**: ALB returns 502 errors
**Causes**:
- EC2 instance not running
- Apache not started
- Security group blocking traffic
- Health checks failing

**Solutions**:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check EC2 instance status
aws ec2 describe-instances --instance-ids <instance-id>

# Use AWS Systems Manager Session Manager (if needed)
aws ssm start-session --target <instance-id>
sudo systemctl status httpd
```

#### 2. Health Check Failures
**Symptoms**: Target shows as unhealthy
**Causes**:
- User data script failed
- Apache not installed/started
- Network connectivity issues

**Solutions**:
```bash
# Check user data logs (via Systems Manager)
aws ssm start-session --target <instance-id>
sudo cat /var/log/user-data.log
sudo cat /var/log/web-setup.log

# Test Apache locally (via Systems Manager)
curl http://localhost/
```

#### 3. Instance Access Issues
**Symptoms**: Cannot access EC2 instance directly
**Causes**:
- Instance in private subnet (by design)
- No SSH key configured
- Security group restrictions

**Solutions**:
- Use AWS Systems Manager Session Manager for access
- Create a bastion host in public subnet if SSH access is needed
- Monitor through ALB health checks and status pages
- Use CloudWatch logs for troubleshooting

### Debugging Commands

#### Check Infrastructure Status
```bash
# ALB health
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names app-gateway-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# EC2 status
aws ec2 describe-instances --instance-ids $(terraform output -raw vm_instance_id) --query 'Reservations[0].Instances[0].State.Name'

# Security groups
aws ec2 describe-security-groups --group-ids $(terraform output -raw alb_security_group_id)
```

#### Test Application
```bash
# Test ALB
curl -v http://$(terraform output -raw alb_dns_name)/

# Test health endpoint
curl http://$(terraform output -raw alb_dns_name)/health

# Test status page
curl http://$(terraform output -raw alb_dns_name)/status
```

## 🧹 Cleanup

### Destroy Infrastructure
```bash
terraform destroy
```

### Manual Cleanup (if needed)
```bash
# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>

# Delete EC2 instance
aws ec2 terminate-instances --instance-ids <instance-id>

# Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id <nat-gateway-id>

# Delete VPC (will delete all resources)
aws ec2 delete-vpc --vpc-id <vpc-id>
```

## 🔒 Security Best Practices

### Network Security
- ✅ EC2 instance in private subnet
- ✅ ALB in public subnets with restricted security groups
- ✅ NAT Gateway for controlled internet access
- ✅ Security groups with minimal required access

### Access Control
- ✅ Security groups restrict traffic to ALB only
- ✅ No direct internet access to EC2 instance
- ✅ Instance access via AWS Systems Manager (if needed)

### Monitoring
- ✅ Health checks for automatic failover
- ✅ Comprehensive logging
- ✅ Status endpoints for monitoring

## 📈 Scaling & Production Considerations

### Auto Scaling
To add auto scaling:
1. Create Auto Scaling Group
2. Replace single EC2 instance with ASG
3. Update target group attachment
4. Configure scaling policies

### High Availability
- ✅ Multi-AZ deployment
- ✅ ALB across two availability zones
- ✅ Health checks and automatic failover

### Monitoring & Alerting
Consider adding:
- CloudWatch alarms for ALB metrics
- Application performance monitoring
- Log aggregation (CloudWatch Logs)
- Custom metrics and dashboards

### SSL/TLS
To enable HTTPS:
1. Request SSL certificate from ACM
2. Create HTTPS listener (port 443)
3. Update security groups
4. Configure redirect from HTTP to HTTPS

## 📝 Outputs

After successful deployment:
```bash
terraform output
```

Available outputs:
- `alb_dns_name`: ALB DNS name for application access
- `health_check_url`: Direct link to health check endpoint
- `status_page_url`: Direct link to server status page
- `vm_private_ip`: Private IP of EC2 instance

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review AWS documentation
3. Check Terraform logs
4. Create an issue in the repository

---

**Note**: This infrastructure incurs AWS charges. Monitor your usage and clean up resources when not needed. 