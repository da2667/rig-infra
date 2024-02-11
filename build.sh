#!/bin/bash

region="ap-southeast-2"
env="dev"
infra_repo="https://github.com/da2667/rig-infra.git"
infra_codestar_arn="arn:aws:codestar-connections:ap-southeast-2:973432020568:connection/64bf4aae-538e-4538-ad70-692d56187b73"
infra_repo_id="da2667/rig-infra"

echo "Deploying pipeline(s)..."
aws cloudformation deploy \
    --stack-name rig-${env}-infra-codepipeline-stack \
    --template-file ./infra/pipeline/pipeline.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineName="rig-${env}-infra-pipeline" GitHubRepo=$infra_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-artifacts-bucket-210023018938" CodeStarConnectionArn=$infra_codestar_arn GitHubRepoId=$infra_repo_id GitHubBranch=$env

# Add frontend app pipeline here
# Add backend app pipeline here

echo "Deploying networking..."
aws cloudformation deploy --stack-name rig-${ENV}-VPC-Stack --template-file ./infra/vpc/vpc.yml --capabilities CAPABILITY_NAMED_IAM  --parameter-overrides VpcName='rig-${Environment}-VPC' AZ1='ap-southeast-2a' AZ2='ap-southeast-2b'
VPCID=$(aws cloudformation --region $REGION describe-stacks --stack-name rig-${Environment}-VPC-Stack --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)

echo "Deploying security groups..."
aws cloudformation deploy --stack-name rig-Frontend-SG-Stack --template-file ./infra/security_groups/sg-cidr.yml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides SGName='rig-Frontend-SG' SGDescription='test' VpcId=$VPCID
aws cloudformation deploy --stack-name rig-API-SG-Stack --template-file ./infra/security_groups/rig-API-SG.yml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation deploy --stack-name rig-DB-SG-Stack --template-file ./infra/security_groups/rig-DB-SG.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying EC2 instances..."
aws cloudformation deploy --stack-name rig-Frontend-Instance-Stack --template-file ./infra/ec2/rig-Frontend-Instance.yml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation deploy --stack-name rig-API-Instance-Stack --template-file ./infra/ec2/rig-API-Instance.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying RDS..."
aws cloudformation deploy --stack-name rig-DB-RDS-Stack --template-file ./infra/rds/rig-DB-RDS.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying CloudWatch Monitoring stack..."
aws cloudformation deploy --stack-name rig-${Environment}-Monitoring-Stack --template-file ./infra/monitoring/monitoring.yml --capabilities CAPABILITY_NAMED_IAM