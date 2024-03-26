#!/bin/bash

region="ap-southeast-2"
env="dev"
infra_repo="https://github.com/da2667/rig-infra.git"
frontend_repo="https://github.com/da2667/rig.git"
api_repo="https://github.com/da2667/rig-api.git"
codestar_arn="arn:aws:codestar-connections:ap-southeast-2:973432020568:connection/f699a370-e94a-413b-9657-5673b66aff27"
infra_repo_id="da2667/rig-infra"
frontend_repo_id="da2667/rig"
api_repo_id="da2667/rig-api"
ami_id="ami-02eec49345a878486"
hosted_zone_id="Z06281253VPT3IJVNJVUU"

#echo "Deploying infra pipeline..."
#aws cloudformation deploy \
#    --stack-name rig-${env}-infra-codepipeline-stack \
 #   --template-file ./infra/pipeline/infra_pipeline.yml \
  #  --capabilities CAPABILITY_NAMED_IAM \
   # --parameter-overrides CodePipelineName="rig-${env}-infra-codepipeline" InfraRepo=$infra_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-infra-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn InfraGitHubRepoId=$infra_repo_id GitHubBranch=$env

echo "Deploying networking..."
aws cloudformation deploy \
    --stack-name rig-${env}-VPC-Stack \
    --template-file ./infra/vpc/vpc.yml \
    --capabilities CAPABILITY_NAMED_IAM  \
    --parameter-overrides VpcName="rig-${env}-VPC" AZ1="ap-southeast-2a" AZ2="ap-southeast-2b"

vpc_id=$(aws cloudformation --region $region describe-stacks --stack-name rig-${env}-VPC-Stack --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)

frontend_subnet_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id Name=cidr-block,Values="10.0.0.0/24" --query 'Subnets[*].[SubnetId]' --output text)
api_subnet_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id Name=cidr-block,Values="10.0.1.0/24" --query 'Subnets[*].[SubnetId]' --output text)
db_subnet_1_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id Name=cidr-block,Values="10.0.2.0/24" --query 'Subnets[*].[SubnetId]' --output text)
db_subnet_2_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id Name=cidr-block,Values="10.0.3.0/24" --query 'Subnets[*].[SubnetId]' --output text)

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

db_sg_id=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpc_id Name=group-name,Values=rig-${env}-db-sg --query 'SecurityGroups[*].[GroupId]' --output text)

echo "Deploying EC2 instances..."

aws cloudformation deploy \
    --stack-name rig-frontend-instance-stack \
    --template-file ./infra/ec2/frontend_instance.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SecurityGroup=$frontend_sg_id KeyPairName="rig-${env}-frontend-keypair" ImageId=$ami_id InstanceType="t2.medium" InstanceName="rig-${env}-frontend-instance" SubnetId=$frontend_subnet_id

frontend_instance_id=$(aws ec2 describe-instances --filter Name=subnet-id,Values=$frontend_subnet_id --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
frontend_instance_ip=$(aws ec2 describe-addresses --filter Name=instance-id,Values=$frontend_instance_id --query 'Addresses[0].PublicIp' --output text)

aws cloudformation deploy \
    --stack-name rig-api-instance-stack \
    --template-file ./infra/ec2/api_instance.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides SecurityGroup=$api_sg_id KeyPairName="rig-${env}-api-keypair" ImageId=$ami_id InstanceType="t2.medium" InstanceName="rig-${env}-api-instance" SubnetId=$api_subnet_id

api_instance_id=$(aws ec2 describe-instances --filter Name=subnet-id,Values=$api_subnet_id --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
api_instance_ip=$(aws ec2 describe-addresses --filter Name=instance-id,Values=$api_instance_id --query 'Addresses[0].PublicIp' --output text)

echo "Deploying RDS..."
aws cloudformation deploy \
    --stack-name rig-DB-RDS-Stack \
    --template-file ./infra/rds/rds.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides Environment=${env} AllocatedStorage=20 AZ="ap-southeast-2a" DBSubnet1=$db_subnet_1_id DBSubnet2=$db_subnet_2_id DBInstanceClass="db.t2.micro" DBName=rigdb DBPort=3306 DBUser=dbadmin DBSecurityGroup=$db_sg_id

db_instance_hostname=$(aws rds describe-db-instances --db-instance-identifier rig-${env}-db --query 'DBInstances[0].Endpoint.Address' --output text)

echo "Deploying CloudWatch Monitoring stack..."
aws cloudformation deploy \
    --stack-name rig-${env}-monitoring-stack \
    --template-file ./infra/monitoring/monitoring.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides DashboardName="rig-${env}-dashboard" FrontendInstanceId=$frontend_instance_id

echo "Deploying front and backend pipelines..."

aws cloudformation deploy \
    --stack-name rig-${env}-frontend-codepipeline-stack \
    --template-file ./infra/pipeline/frontend_pipeline.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineName="rig-${env}-frontend-codepipeline" FrontendRepo=$frontend_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-frontend-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn FrontendGitHubRepoId=$frontend_repo_id GitHubBranch=$env ApplicationName="rig-${env}-frontend-application" InstanceName="rig-${env}-frontend-instance"

aws cloudformation deploy \
    --stack-name rig-${env}-api-codepipeline-stack \
    --template-file ./infra/pipeline/api_pipeline.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineName="rig-${env}-api-codepipeline" ApiRepo=$api_repo CodeBuildImage="aws/codebuild/amazonlinux2-x86_64-standard:5.0" BucketName="rig-${env}-api-artifacts-bucket-210023018938" CodeStarConnectionArn=$codestar_arn ApiGitHubRepoId=$api_repo_id GitHubBranch=$env ApplicationName="rig-${env}-api-application" InstanceName="rig-${env}-api-instance"

aws cloudformation deploy \
    --stack-name rig-${env}-route53-stack \
    --template-file ./infra/r53/route53.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides Environment=${env} DomainName="rigapp.io" HostedZoneId=${hosted_zone_id} FrontendInstanceIP=$frontend_instance_ip APIInstanceIP=$api_instance_ip DBInstanceHostname=$db_instance_hostname