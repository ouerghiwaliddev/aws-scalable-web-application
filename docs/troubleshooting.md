# Troubleshooting Guide

## Issue Encountered

After deploying the architecture:

CloudFront → WAF → ALB → Auto Scaling Group → EC2 → RDS

the application returned:

```text
504 Gateway Timeout
```

CloudFront reported that it could not connect to the origin.

---

## Symptoms

### CloudFront

```text
504 Gateway Timeout
```

### Application Load Balancer

```text
The ALB DNS name was not serving the application.
```

### Target Group

Targets were marked as:

```text
Unhealthy
```

Reason:

```text
Target.Timeout
Request timed out
```

---

## Investigation Process

### Verify CloudFront

Verified that the CloudFront distribution was properly deployed and configured.

### Verify ALB

Confirmed that the Application Load Balancer existed and was associated with the correct Target Group.

### Verify Target Group

Health check configuration:

```text
Port: 80
Path: /
```

Configuration was correct.

### Verify EC2 Instances

Connected to an EC2 instance through Session Manager.

Checked NGINX:

```bash
sudo systemctl status nginx
```

Result:

```text
active (running)
```

Verified local connectivity:

```bash
curl localhost
```

Response:

```html
<h1>AWS Scalable Web Application</h1>
<p>Deployed using Auto Scaling Group and ALB.</p>
```

NGINX was functioning correctly.

---

## Root Cause

The Security Group assigned to the application tier (app-sg) was misconfigured.

Incorrect rule:

```text
MYSQL/Aurora
TCP 3306
Source: sg-xxxxxxxx
```

Expected rule:

```text
HTTP
TCP 80
Source: alb-sg
```

Because port 80 was not allowed from the Application Load Balancer Security Group, the ALB could not reach the EC2 instances.

Flow blocked:

```text
ALB
  ↓
EC2 Port 80
```

This resulted in:

```text
Target.Timeout
→ Unhealthy Targets
→ ALB Failure
→ CloudFront 504 Gateway Timeout
```

---

## Resolution

Updated inbound rules of app-sg.

Removed:

```text
TCP 3306
```

Added:

```text
Type: HTTP
Port: 80
Source: alb-sg
```

---

## Validation

After updating the Security Group:

```bash
aws elbv2 describe-target-health
```

Result:

```text
State: healthy
State: healthy
```

The Application Load Balancer became operational.

Verified:

```text
http://webapp-alb-xxxxxxxx.eu-north-1.elb.amazonaws.com
```

Application successfully displayed:

```html
<h1>AWS Scalable Web Application</h1>
<p>Deployed using Auto Scaling Group and ALB.</p>
```

CloudFront was also able to serve the application successfully.

---

## Lessons Learned

1. Always validate Security Group rules before troubleshooting application services.
2. Verify Target Group health status before investigating CloudFront issues.
3. Test the Application Load Balancer directly before testing CloudFront.
4. Use CloudWatch metrics and Target Health information to accelerate troubleshooting.
5. Security Group misconfigurations are one of the most common causes of ALB health-check failures.
