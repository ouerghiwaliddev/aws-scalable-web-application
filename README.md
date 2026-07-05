# Scalable Web Application on AWS with ALB, Auto Scaling & Multi-AZ RDS

## 📌 Project Overview

This project demonstrates the deployment of a production-grade, highly available and scalable web application on AWS.

The architecture follows AWS Well-Architected Framework principles by implementing:

- High Availability across multiple Availability Zones
- Auto Scaling EC2 application tier
- Load balancing with Application Load Balancer (ALB)
- Multi-AZ managed database with Amazon RDS
- Edge caching using CloudFront
- Secure access through AWS Systems Manager Session Manager
- Application protection with AWS WAF
- Monitoring and alerting through CloudWatch and SNS

---

## 🏗 Architecture Diagram

```text
Internet
    │
    ▼
Amazon Route53
    │
    ▼
Amazon CloudFront
    │
    ▼
AWS WAF
    │
    ▼
Application Load Balancer
    │
    ▼
EC2 Auto Scaling Group (Multi-AZ)
    │
    ▼
Amazon RDS Multi-AZ
```

---

## 🎯 Objectives

- Create a secure AWS network architecture.
- Deploy scalable web application servers.
- Ensure database high availability.
- Implement automatic scaling based on traffic.
- Secure the application against common web attacks.
- Monitor infrastructure health and performance.
- Eliminate the need for bastion hosts using Session Manager.

---

# AWS Services Used

- VPC
- EC2
- Auto Scaling Group
- Application Load Balancer
- CloudFront
- RDS Multi-AZ
- Route 53
- Security Groups
- Network ACLs
- NAT Gateway
- AWS WAF
- Systems Manager
- CloudWatch
- SNS

---

# Deployment Steps

1. Create VPC and networking components.
2. Create Security Groups.
3. Deploy RDS Multi-AZ.
4. Create Launch Template.
5. Create Auto Scaling Group.
6. Deploy Application Load Balancer.
7. Configure AWS WAF.
8. Configure CloudFront.
9. Configure Route53.
10. Configure CloudWatch and SNS.
11. Validate High Availability and Auto Scaling.

---

# Skills Demonstrated

- AWS Networking
- High Availability Architectures
- Security Best Practices
- Monitoring & Observability
- Auto Scaling
- Load Balancing
- Cloud Architecture Design
- Route53 DNS Management
- RDS Administration
- AWS WAF
- CloudFront Optimization
