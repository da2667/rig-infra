#!/bin/bash

REGION="ap-southeast-2"
ENVIRONMENT="Dev"

echo "Deploying pipeline(s)..."
aws cloudformation deploy --stack-name Rig-CodePipeline-Infra-Stack --template-file ./infra/cicd/Rig-CodePipeline-Infra.yml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides file://infra/cicd/config.json
# Add frontend app pipeline here
# Add backend app pipeline here

echo "Deploying networking..."
aws cloudformation deploy --stack-name Rig-Main-VPC-Stack --template-file ./infra/vpc/vpc.yml --capabilities CAPABILITY_NAMED_IAM  --parameter-overrides file://infra/vpc/config.json
VPCID=$(aws cloudformation --region $REGION describe-stacks --stack-name Rig-Main-VPC-Stack --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)

echo "Deploying security groups..."
aws cloudformation deploy --stack-name Rig-Frontend-SG-Stack --template-file ./infra/security_groups/sg-cidr.yml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides SGName='Rig-Frontend-SG' SGDescription='test' VpcId=$VPCID
aws cloudformation deploy --stack-name Rig-API-SG-Stack --template-file ./infra/security_groups/Rig-API-SG.yml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation deploy --stack-name Rig-DB-SG-Stack --template-file ./infra/security_groups/Rig-DB-SG.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying EC2 instances..."
aws cloudformation deploy --stack-name Rig-Frontend-Instance-Stack --template-file ./infra/ec2/Rig-Frontend-Instance.yml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation deploy --stack-name Rig-API-Instance-Stack --template-file ./infra/ec2/Rig-API-Instance.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying RDS..."
aws cloudformation deploy --stack-name Rig-DB-RDS-Stack --template-file ./infra/rds/Rig-DB-RDS.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying CloudWatch Monitoring stack..."
aws cloudformation deploy --stack-name Rig-${Environment}-Monitoring-Stack --template-file ./infra/monitoring/monitoring.yml --capabilities CAPABILITY_NAMED_IAM