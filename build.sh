#!/bin/bash

region="ap-southeast-2"
env="dev"
infra_repo="https://github.com/da2667/rig-infra.git"
frontend_repo="https://github.com/da2667/rig.git"
codestar_arn="arn:aws:codestar-connections:ap-southeast-2:973432020568:connection/5a6b5fdd-70b5-4775-99ad-34df2abb3638"
infra_repo_id="da2667/rig-infra"
frontend_repo_id="da2667/rig"

echo "Deploying pipeline(s)..."
aws cloudformation deploy \
    --stack-name rig-${env}-codepipeline-stack \
    --template-file ./infra/pipeline/pipeline.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineName="rig-${env}-codepipeline" InfraRepo=$infra_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn GitHubRepoId=$infra_repo_id GitHubBranch=$env

echo "Deploying networking..."
aws cloudformation deploy \
    --stack-name rig-${env}-VPC-Stack \
    --template-file ./infra/vpc/vpc.yml \
    --capabilities CAPABILITY_NAMED_IAM  \
    --parameter-overrides VpcName="rig-${env}-VPC" AZ1="ap-southeast-2a" AZ2="ap-southeast-2b"

vpc_id=$(aws cloudformation --region $region describe-stacks --stack-name rig-${env}-VPC-Stack --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)

echo "Deploying security groups..."
aws cloudformation deploy \
    --stack-name rig-Frontend-SG-Stack \
    --template-file ./infra/sg/sg-cidr.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SGName="rig-${env}-frontend-sg" SGDescription="Frontend application access security group for Rig" VpcId=$vpc_id InboundCIDR="0.0.0.0/0"

# aws cloudformation deploy --stack-name rig-API-SG-Stack --template-file ./infra/sg/sg.yml --capabilities CAPABILITY_NAMED_IAM
# aws cloudformation deploy --stack-name rig-DB-SG-Stack --template-file ./infra/sg/sg.yml --capabilities CAPABILITY_NAMED_IAM

# echo "Deploying EC2 instances..."
# aws cloudformation deploy --stack-name rig-Frontend-Instance-Stack --template-file ./infra/ec2/rig-Frontend-Instance.yml --capabilities CAPABILITY_NAMED_IAM
# aws cloudformation deploy --stack-name rig-API-Instance-Stack --template-file ./infra/ec2/rig-API-Instance.yml --capabilities CAPABILITY_NAMED_IAM

# echo "Deploying RDS..."
# aws cloudformation deploy --stack-name rig-DB-RDS-Stack --template-file ./infra/rds/rig-DB-RDS.yml --capabilities CAPABILITY_NAMED_IAM

# echo "Deploying CloudWatch Monitoring stack..."
# aws cloudformation deploy \
#    --stack-name rig-${env}-monitoring-stack \
#    --template-file ./infra/monitoring/monitoring.yml \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides DashboardName="rig-${env}-dashboard"