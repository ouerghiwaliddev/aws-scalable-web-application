# Guide de déploiement — Application Web Scalable sur AWS (ALB, Auto Scaling, RDS Multi-AZ)

Ce guide détaille, étape par étape, comment déployer l'architecture décrite dans le README, à la fois **via la console AWS** et **via AWS CLI**.

> ⚠️ Remplace les valeurs entre `<...>` (IDs, noms, mots de passe, régions) par les tiennes avant d'exécuter les commandes.

---

## 0. Prérequis

- Un compte AWS avec les droits IAM nécessaires (VPC, EC2, RDS, ELB, ASG, WAF, CloudFront, Route53, CloudWatch, SNS).
- AWS CLI v2 installé et configuré (`aws configure`).
- Une paire de clés EC2 (ou utilisation exclusive de Session Manager, recommandé — pas de SSH).
- Un nom de domaine géré (optionnel, pour Route53).

```bash
aws configure
aws sts get-caller-identity   # vérifier l'identité/région active
```

---

## 1. Créer le VPC et les composants réseau

### Console AWS
1. **VPC** → *Create VPC* → choisir **VPC and more** (assistant).
2. Renseigner :
   - Nom : `webapp-vpc`
   - CIDR : `10.0.0.0/16`
   - Nombre d'AZ : 2 (haute disponibilité)
   - Sous-réseaux publics : 2 (pour ALB / NAT)
   - Sous-réseaux privés : 2 (pour EC2 et RDS)
   - NAT Gateway : **1 par AZ** (ou 1 pour économiser en test)
3. Cliquer *Create VPC*.

### AWS CLI
```bash
# VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=webapp-vpc}]'

# Sous-réseaux publics
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.1.0/24 \
  --availability-zone <REGION>a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1}]'
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.2.0/24 \
  --availability-zone <REGION>b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-2}]'

# Sous-réseaux privés
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.11.0/24 \
  --availability-zone <REGION>a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1}]'
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.12.0/24 \
  --availability-zone <REGION>b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-2}]'

# Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=webapp-igw}]'
aws ec2 attach-internet-gateway --vpc-id <VPC_ID> --internet-gateway-id <IGW_ID>

# NAT Gateway (nécessite une EIP)
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway --subnet-id <PUBLIC_SUBNET_1> --allocation-id <EIP_ALLOC_ID>

# Route tables
aws ec2 create-route-table --vpc-id <VPC_ID>
aws ec2 create-route --route-table-id <PUBLIC_RT_ID> --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID>
aws ec2 associate-route-table --subnet-id <PUBLIC_SUBNET_1> --route-table-id <PUBLIC_RT_ID>
```

---

## 2. Créer les Security Groups

### Console AWS
- **EC2 → Security Groups → Create security group**
  - `alb-sg` : Inbound HTTP(80)/HTTPS(443) depuis `0.0.0.0/0`
  - `app-sg` : Inbound HTTP(80) uniquement depuis `alb-sg`
  - `rds-sg` : Inbound MySQL/Postgres (3306/5432) uniquement depuis `app-sg`

### AWS CLI
```bash
# SG pour l'ALB
aws ec2 create-security-group --group-name alb-sg --description "ALB SG" --vpc-id <VPC_ID>
aws ec2 authorize-security-group-ingress --group-id <ALB_SG_ID> --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id <ALB_SG_ID> --protocol tcp --port 443 --cidr 0.0.0.0/0

# SG pour les instances applicatives
aws ec2 create-security-group --group-name app-sg --description "App tier SG" --vpc-id <VPC_ID>
aws ec2 authorize-security-group-ingress --group-id <APP_SG_ID> --protocol tcp --port 80 --source-group <ALB_SG_ID>

# SG pour RDS
aws ec2 create-security-group --group-name rds-sg --description "RDS SG" --vpc-id <VPC_ID>
aws ec2 authorize-security-group-ingress --group-id <RDS_SG_ID> --protocol tcp --port 3306 --source-group <APP_SG_ID>
```

---

## 3. Déployer RDS Multi-AZ

### Console AWS
1. **RDS → Create database** → *Standard create*.
2. Moteur : MySQL / PostgreSQL (selon besoin).
3. Templates : *Production*.
4. Deployment options : **Multi-AZ DB instance**.
5. Renseigner identifiants, classe d'instance (`db.t3.medium` par ex.).
6. Connectivity : sélectionner le VPC, les sous-réseaux privés, et `rds-sg`.
7. Désactiver l'accès public.
8. Créer un **DB subnet group** couvrant les 2 AZ si pas déjà fait.

### AWS CLI
```bash
# DB subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name webapp-db-subnet-group \
  --db-subnet-group-description "Private subnets for RDS" \
  --subnet-ids <PRIVATE_SUBNET_1> <PRIVATE_SUBNET_2>

# Instance RDS Multi-AZ
aws rds create-db-instance \
  --db-instance-identifier webapp-db \
  --db-instance-class db.t3.medium \
  --engine mysql \
  --master-username admin \
  --master-user-password <PASSWORD> \
  --allocated-storage 20 \
  --vpc-security-group-ids <RDS_SG_ID> \
  --db-subnet-group-name webapp-db-subnet-group \
  --multi-az \
  --no-publicly-accessible \
  --backup-retention-period 7
```

---

## 4. Créer le Launch Template

### Console AWS
1. **EC2 → Launch Templates → Create launch template**.
2. AMI : Amazon Linux 2023 (ou custom AMI avec l'app pré-installée).
3. Instance type : `t3.micro` / `t3.small`.
4. Security group : `app-sg`.
5. IAM instance profile : rôle avec `AmazonSSMManagedInstanceCore` (pour Session Manager, sans bastion).
6. User data : script d'installation (ex. installer nginx/app + agent CloudWatch).

### AWS CLI
```bash
aws ec2 create-launch-template \
  --launch-template-name webapp-lt \
  --version-description "v1" \
  --launch-template-data '{
    "ImageId": "<AMI_ID>",
    "InstanceType": "t3.micro",
    "SecurityGroupIds": ["<APP_SG_ID>"],
    "IamInstanceProfile": {"Name": "<SSM_INSTANCE_PROFILE>"},
    "UserData": "<BASE64_USERDATA_SCRIPT>"
  }'
```

---

## 5. Créer l'Auto Scaling Group

### Console AWS
1. **EC2 → Auto Scaling Groups → Create Auto Scaling group**.
2. Sélectionner le Launch Template créé.
3. VPC + sous-réseaux **privés** (2 AZ).
4. Attacher au **Target Group** de l'ALB (créé à l'étape suivante, ou après coup).
5. Capacité : min=2, desired=2, max=6 (exemple).
6. Politique de scaling : *Target tracking* sur CPU (ex. 60%).

### AWS CLI
```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name webapp-asg \
  --launch-template LaunchTemplateName=webapp-lt,Version='$Latest' \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "<PRIVATE_SUBNET_1>,<PRIVATE_SUBNET_2>" \
  --target-group-arns <TARGET_GROUP_ARN> \
  --health-check-type ELB --health-check-grace-period 300

# Politique de scaling (target tracking CPU)
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name webapp-asg \
  --policy-name cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {"PredefinedMetricType": "ASGAverageCPUUtilization"},
    "TargetValue": 60.0
  }'
```

---

## 6. Déployer l'Application Load Balancer

### Console AWS
1. **EC2 → Load Balancers → Create Load Balancer → Application Load Balancer**.
2. Scheme : Internet-facing.
3. Sous-réseaux publics (2 AZ).
4. Security group : `alb-sg`.
5. Créer un **Target Group** (type instance, port 80, health check `/health`).
6. Listener HTTP:80 (et HTTPS:443 avec certificat ACM si disponible).

### AWS CLI
```bash
# Target Group
aws elbv2 create-target-group \
  --name webapp-tg --protocol HTTP --port 80 --vpc-id <VPC_ID> \
  --health-check-path /health --target-type instance

# Load Balancer
aws elbv2 create-load-balancer \
  --name webapp-alb --subnets <PUBLIC_SUBNET_1> <PUBLIC_SUBNET_2> \
  --security-groups <ALB_SG_ID> --scheme internet-facing --type application

# Listener
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=<TARGET_GROUP_ARN>
```

---

## 7. Configurer AWS WAF

### Console AWS
1. **WAF & Shield → Web ACLs → Create web ACL**.
2. Resource type : ALB (ou CloudFront selon où l'attacher).
3. Ajouter des **règles managées AWS** : `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesSQLiRuleSet`, rate-based rule anti-flood.
4. Associer le Web ACL à l'ALB (ou à la distribution CloudFront).

### AWS CLI
```bash
aws wafv2 create-web-acl \
  --name webapp-waf --scope REGIONAL \
  --default-action Allow={} \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=webapp-waf \
  --rules file://waf-rules.json

aws wafv2 associate-web-acl \
  --web-acl-arn <WEB_ACL_ARN> --resource-arn <ALB_ARN>
```

---

## 8. Configurer CloudFront

### Console AWS
1. **CloudFront → Create distribution**.
2. Origin : DNS de l'ALB.
3. Origin Protocol Policy : HTTPS only (ou match viewer).
4. Cache policy : selon contenu statique/dynamique.
5. WAF : attacher le Web ACL (scope CLOUDFRONT si distinct du régional).
6. Certificat SSL : ACM (us-east-1 obligatoire pour CloudFront).

### AWS CLI
```bash
aws cloudfront create-distribution \
  --origin-domain-name <ALB_DNS_NAME> \
  --default-root-object index.html
```

---

## 9. Configurer Route 53

### Console AWS
1. **Route 53 → Hosted zones → Create record**.
2. Type : **A – Alias**.
3. Route trafic vers la distribution CloudFront (ou l'ALB directement).

### AWS CLI
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.<domaine>.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<CLOUDFRONT_HOSTED_ZONE_ID>",
          "DNSName": "<CLOUDFRONT_DOMAIN_NAME>",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

---

## 10. Configurer CloudWatch et SNS

### Console AWS
1. **SNS → Create topic** (`webapp-alerts`) → ajouter un abonnement email.
2. **CloudWatch → Alarms → Create alarm** :
   - CPU ASG > 70% pendant 5 min
   - Health checks ALB (unhealthy hosts)
   - RDS : CPU, stockage, connexions
3. Associer chaque alarme au topic SNS.

### AWS CLI
```bash
# Topic SNS
aws sns create-topic --name webapp-alerts
aws sns subscribe --topic-arn <TOPIC_ARN> --protocol email --notification-endpoint <TON_EMAIL>

# Alarme CloudWatch (exemple CPU ASG)
aws cloudwatch put-metric-alarm \
  --alarm-name webapp-high-cpu \
  --metric-name CPUUtilization --namespace AWS/EC2 \
  --statistic Average --period 300 --threshold 70 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 \
  --dimensions Name=AutoScalingGroupName,Value=webapp-asg \
  --alarm-actions <TOPIC_ARN>
```

---

## 11. Valider la haute disponibilité et l'Auto Scaling

- **Test HA RDS** : forcer un failover manuel et vérifier la reprise.
  ```bash
  aws rds reboot-db-instance --db-instance-identifier webapp-db --force-failover
  ```
- **Test Auto Scaling** : générer de la charge CPU (ex. `stress` sur une instance) et observer l'ASG scaler dans la console ou via :
  ```bash
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names webapp-asg
  ```
- **Test résilience AZ** : arrêter volontairement les instances d'une AZ et vérifier que l'ALB route uniquement vers les instances saines.
- **Test WAF** : envoyer une requête avec payload SQLi/XSS de test et vérifier le blocage dans les logs WAF.

---

## Nettoyage (éviter les coûts inutiles)

```bash
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name webapp-asg --force-delete
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>
aws rds delete-db-instance --db-instance-identifier webapp-db --skip-final-snapshot
aws cloudfront delete-distribution --id <DISTRIBUTION_ID> --if-match <ETAG>
aws ec2 delete-nat-gateway --nat-gateway-id <NAT_GW_ID>
```

---

*Astuce : pour un déploiement reproductible, envisage de convertir ces commandes en template **Terraform** ou **AWS CloudFormation** — je peux te le préparer si tu veux.*
