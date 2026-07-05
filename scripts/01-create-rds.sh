#!/bin/bash

aws rds create-db-instance \
  --db-instance-identifier webapp-db \
  --db-instance-class db.t4g.micro \
  --engine mysql \
  --master-username admin \
  --master-user-password 'ChangeMe123!' \
  --allocated-storage 20 \
  --vpc-security-group-ids <RDS_SG_ID> \
  --db-subnet-group-name <DB_SUBNET_GROUP> \
  --no-publicly-accessible \
  --backup-retention-period 7