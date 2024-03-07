# rig-infra

This repository deploys the infrastructure for the Rig Chat Application on AWS using AWS CloudFormation. YAML is used for the template code.

## Resources Deployed

This repo will deploy the following resources (per environment - ```dev/stg/prod```):

- 3 x CodePipelines (one for Frontend, one for Backend/API, and one for the Infrastructure)
- CloudWatch Monitoring Stack
- 2 x EC2 Instances (one for Frontend, one for Backend/API)
- 3 x Security Groups (Frontend, API and DB)
- RDS MySQL Instance (for Database)
- VPC Stack (contains VPC, Route Tables, Subnets - Frontend, Backend, 2 x DB Subnets for DB Subnet Group, etc.)
- Revelant IAM roles and policies
- Route 53 DNS stack

## How it works?

### CI/CD Pipelines

The Frontend and API Pipelines contain a Source, Build and Deploy Phase using a CodeStar Connection, CodeBuild Project and a CodeDeploy Application which then deploys the source code and runs it on the appropriate EC2 instance. The Infra Pipeline is different, having the CodeStar Connection with a CodeBuild project, which runs the ```build.sh``` script and deploys the CloudFormation stacks using that script.

### Monitoring

The CloudWatch Monitoring Stack has a CloudWatch Dashboard, which displays multiple metrics across the Instances such as CPUUtilization, etc. Alarms will eventually be setup for SNS notifications.

### Route 53 (DNS)

The main domain name for the Rig application is ```rigapp.io```, SSL certificates will need to be setup via ACM and deployed via CloudFormation before a full development, staging and production deployment.

The naming convention for the DNS is ```<service>.<environment>.rigapp.io```. By service, I mean either the Frontend, API or Database and the environment is either dev/stg/prod. The expection is prod, which should redirect to ```rigapp.io``` from ```prod.rigapp.io```.

So the possible combinations are:
~~~
Frontend Production | rigapp.io
API Production | api.rigapp.io
Database Production | db.rigapp.io
Frontend Staging | stg.rigapp.io
API Staging | api.stg.rigapp.io
Database Staging | db.stg.rigapp.io
Frontend Dev | dev.rigapp.io
API Dev | api.dev.rigapp.io
Database Dev | db.dev.rigapp.io
~~~
## Todo

The following is the stuff that I really want to do ASAP:

- Finish Infrastructure Repo (foundational)
- Add and plan for Application Load Balancer Routing
- Add and plan for more redundancy/failover (multiple AZs, subnets and failover instances, etc)
- Add SNS stack for pipeline and monitoring notifications
- Add SSL certificates

##

### Copyright Dylan Armstrong 2024

##

