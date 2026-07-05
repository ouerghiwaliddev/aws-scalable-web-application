#!/bin/bash

echo "Deleting Auto Scaling Group..."

aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name webapp-asg \
  --force-delete

echo "Deleting Load Balancer..."

aws elbv2 delete-load-balancer \
  --load-balancer-arn <ALB_ARN>

echo "Deleting Target Group..."

aws elbv2 delete-target-group \
  --target-group-arn <TARGET_GROUP_ARN>

echo "Deleting RDS..."

aws rds delete-db-instance \
  --db-instance-identifier webapp-db \
  --skip-final-snapshot

echo "Cleanup completed."