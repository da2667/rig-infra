#!/bin/bash

region="ap-southeast-2"
env="dev"
infra_repo="https://github.com/da2667/rig-infra.git"
frontend_repo="https://github.com/da2667/rig.git"
codestar_arn="arn:aws:codestar-connections:ap-southeast-2:973432020568:connection/5a6b5fdd-70b5-4775-99ad-34df2abb3638"
infra_repo_id="da2667/rig-infra"
frontend_repo_id="da2667/rig"
ami_id="ami-02eec49345a878486"

#echo "Deploying pipelines..."
#aws cloudformation deploy \
#    --stack-name rig-${env}-infra-codepipeline-stack \
 #   --template-file ./infra/pipeline/infra_pipeline.yml \
  #  --capabilities CAPABILITY_NAMED_IAM \
   # --parameter-overrides CodePipelineName="rig-${env}-infra-codepipeline" InfraRepo=$infra_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-infra-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn InfraGitHubRepoId=$infra_repo_id GitHubBranch=$env

aws cloudformation deploy \
    --stack-name rig-${env}-frontend-codepipeline-stack \
    --template-file ./infra/pipeline/frontend_pipeline.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineName="rig-${env}-frontend-codepipeline" FrontendRepo=$frontend_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-frontend-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn FrontendGitHubRepoId=$frontend_repo_id GitHubBranch=$env ApplicationName="rig-${env}-frontend-application" InstanceName="rig-${env}-frontend-instance"

echo "Deploying networking..."
aws cloudformation deploy \
    --stack-name rig-${env}-VPC-Stack \
    --template-file ./infra/vpc/vpc.yml \
    --capabilities CAPABILITY_NAMED_IAM  \
    --parameter-overrides VpcName="rig-${env}-VPC" AZ1="ap-southeast-2a" AZ2="ap-southeast-2b"

vpc_id=$(aws cloudformation --region $region describe-stacks --stack-name rig-${env}-VPC-Stack --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)

frontend_subnet_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id Name=cidr-block,Values="10.0.0.0/24" --query 'Subnets[*].[SubnetId]' --output text)

echo "Deploying security groups..."
aws cloudformation deploy \
    --stack-name rig-Frontend-SG-Stack \
    --template-file ./infra/sg/sg-cidr.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SGName="rig-${env}-frontend-sg" SGDescription="Frontend application access security group for Rig" VpcId=$vpc_id InboundCIDR="0.0.0.0/0"

frontend_sg_id=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpc_id Name=group-name,Values=rig-${env}-frontend-sg --query 'SecurityGroups[*].[GroupId]' --output text)

aws cloudformation deploy \
    --stack-name rig-api-sg-stack \
    --template-file ./infra/sg/sg.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SGName="rig-${env}-api-sg" SGDescription="API access security group for Rig" VpcId=$vpc_id InboundSG=$frontend_sg_id InboundPort=3001

api_sg_id=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpc_id Name=group-name,Values=rig-${env}-api-sg --query 'SecurityGroups[*].[GroupId]' --output text)

aws cloudformation deploy \
    --stack-name rig-db-sg-stack \
    --template-file ./infra/sg/sg.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SGName="rig-${env}-db-sg" SGDescription="Database security group access from API for the Rig application" VpcId=$vpc_id InboundSG=$api_sg_id InboundPort=3306

echo "Deploying EC2 instances..."

aws cloudformation deploy \
    --stack-name rig-frontend-instance-stack \
    --template-file ./infra/ec2/frontend_instance.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SecurityGroup=$frontend_sg_id KeyPairName="rig-${env}-frontend-keypair" ImageId=$ami_id InstanceType="t2.medium" InstanceName="rig-${env}-frontend-instance" SubnetId=$frontend_subnet_id

frontend_instance_id=$(aws ec2 describe-instances --filter Name=subnet-id,Values=$frontend_subnet_id --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
# aws cloudformation deploy --stack-name rig-api-instance-stack --template-file ./infra/ec2/instance.yml --capabilities CAPABILITY_NAMED_IAM

# echo "Deploying RDS..."
# aws cloudformation deploy --stack-name rig-DB-RDS-Stack --template-file ./infra/rds/rig-DB-RDS.yml --capabilities CAPABILITY_NAMED_IAM

echo "Deploying CloudWatch Monitoring stack..."
aws cloudformation deploy \
    --stack-name rig-${env}-monitoring-stack \
    --template-file ./infra/monitoring/monitoring.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides DashboardName="rig-${env}-dashboard" FrontendInstanceId=$frontend_instance_id