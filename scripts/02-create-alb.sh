#!/bin/bash

aws elbv2 create-target-group \
  --name webapp-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id <VPC_ID> \
  --health-check-path / \
  --target-type instance

aws elbv2 create-load-balancer \
  --name webapp-alb \
  --subnets <PUBLIC_SUBNET_1> <PUBLIC_SUBNET_2> \
  --security-groups <ALB_SG_ID> \
  --scheme internet-facing \
  --type application

echo "ALB and Target Group created."