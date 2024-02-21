# rig-infra

This repository deploys the infrastructure for the Rig Chat Application in AWS using AWS CloudFormation.

### Resources Deployed

This repo will deploy the following resources (per environment - dev/stg/prod):

- Two EC2 instances per environment, one for the Frontend and one for the API. Userdata will pull down the latest code and run it.
- CloudWatch Monitoring Stack
- CI/CD Pipeline (AWS CodePipeline and AWS CodeBuild)
- Amazon RDS Instance running MySQL for the database
- Security Groups
- VPC and Networking Stack

### How it works?

The pipeline will run a bash script in the BUILD stage, building all the infrastructure using CloudFormation stacks via the CLI commands in the script. This will deploy all the neccessary stacks for all the resources required for the three tier web applications including the EC2 instances, networking, security groups, RDS, monitoring, etc.

#### Copyright Dylan Armstrong 2024
