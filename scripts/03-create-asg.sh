#!/bin/bash

aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name webapp-asg \
  --launch-template LaunchTemplateName=MyTemplate-AmazonLinux2023,Version='$Latest' \
  --min-size 2 \
  --max-size 6 \
  --desired-capacity 2 \
  --vpc-zone-identifier "<PRIVATE_SUBNET_1>,<PRIVATE_SUBNET_2>" \
  --target-group-arns <TARGET_GROUP_ARN> \
  --health-check-type ELB \
  --health-check-grace-period 300

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name webapp-asg \
  --policy-name cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
      "PredefinedMetricSpecification": {
        "PredefinedMetricType": "ASGAverageCPUUtilization"
      },
      "TargetValue": 60.0
  }'