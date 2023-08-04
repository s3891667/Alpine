# COSC2759 Assignment 2

## Student details

- Full Name: Khoa Duc Dang Nguyen
- Student ID: S3891667

# Deployment Description
## Overview:
According to the Alpine's team, they have completed with building foo_app Nodejs website application with PostgreSQL database backend using docker images. The application and the back-end are both deployed at patrmitacr.azurecr.io/assignment2app. 

The company wants the product to be scalable and stable therefore they decided to run the images in the EC2 of AWS web services. However, they approach the problem is that the team Clickops throughout the deployment. Therefore, in order to help the team to automate the whole process, I came up with the solution to deploy everything using a shell script as well as one workflow in Github actions.

In total there are 4 parts, including Terraform, Load balancer, S3 bucket and Workflow automate. I will clarify the advantages of each process, teachnologies lised below.  

## AWS Components Deployment:
Firstly, to have the Docker images running on the EC2, I will use Terraform with Ansible Playbook to deploy the required components.

### Terraform:
At the first stage, I will only deploy only the EC2 instance then run the Docker containers in it.

For the EC2 instance to be connected using the public IP. There are components that should be include. Specifically, aws providers for the terraform block, aws instances, aws security group rules and aws ami. 

#### 1. Root Module and Provider
``` tf
terraform {
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
      }
    }
}
provider "aws" {
  region = "us-east-1"
}
```

#### 2. Security Group

``` tf

resource "aws_security_group" "vm_inbound" {
	name = "vm_inbound"
	# SSH
	ingress {
		from_port = 0
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	# HTTP in
	ingress {
		from_port = 0
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
  # Database out 
	egress {
		from_port = 0
		to_port = 5432
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}
```
For the database security group the ingress from port 0 to port 80 will changed into egress as the database instance will receive request from the application therefore sending information for foo_app to display. 

#### 3. AWS instances 
``` tf
# Foo_app
resource "aws_instance" "app" {
	ami = data.aws_ami.ubuntu.id
	instance_type = "t2.micro"
	tags = {
		Name = "foo app"
	}

  #Secret key to connect to the instance
	key_name   = "owenDevOpskey" 
	security_groups = [aws_security_group.vms_for_app]
}

# Database
resource "aws_instance" "db" {
	ami = data.aws_ami.ubuntu.id
	instance_type = "t2.micro"
	tags = {
		Name = "foo db"
	}
	key_name   = "owenDevOpskey" 
	security_groups = [aws_security_group.vms_for_db
}
```
### Ansible and Shell Script
In this secction I will now running the applications' containers in the EC2 instances.

#### Servers Ansible Playbook and Inventory 

``` yml
# All-server-playbook
---
- name: Configure docker for app and database
  hosts: all_servers
  remote_user: ubuntu
  become: yes # sudo

  tasks:
  - name: Install required system packages for Docker
    apt:
      pkg:
        - apt-transport-https
        - ca-certificates
        - curl
        - software-properties-common
        - python3-pip
        - virtualenv
        - python3-setuptools
      state: latest
      update_cache: true

  - name: Add Docker GPG apt Key
    apt_key:
      url: https://download.docker.com/linux/ubuntu/gpg
      state: present

  - name: Add Docker Repository
    apt_repository:
      repo: deb https://download.docker.com/linux/ubuntu jammy stable
      state: present

  - name: Update apt and install docker-ce
    apt:
      name: docker-ce
      state: latest
      update_cache: true

```
The app_playbook.yml file above install Docker for all the instances, foo_app and database. 

``` yml
# All-server-inventory
app_servers:
  hosts:
    app1:
      ansible_host: 

db_servers:
  hosts:
    db1:
      ansible_host: 

all_servers:
  children:
    app_servers:
    db_servers:
```
The ansible_host sections will be replaced with each applications' public ip. The following section will show my solution regarding what to perform within each instance

#### Foo_app
```yml
---
- name: Configure app server
  hosts: app_servers
  remote_user: ubuntu
  become: yes # sudo

  tasks:
  - name: Run foo_app container
    community.docker.docker_container:
      name: "foo_app"
      image: "patrmitacr.azurecr.io/assignment2app:1.0.0"
      env:
        PORT=3001
        DB_HOSTNAME=
        DB_PORT=5432
        DB_USERNAME=pete
        DB_PASSWORD=devops
      published_ports:
        - "0.0.0.0:80:3001"
  - name: Start foo_app container
    become: true
    command: sudo docker start foo_app
```

#### Database
```yml
---
- name: Configure database server
  hosts: db_servers
  remote_user: ubuntu
  become: yes # sudo

  tasks:
  - name: Upload sql file 
    copy: 
      src: ../misc/snapshot-prod-data.sql
      dest:  /home/ubuntu/

  - name: Create & run database container
    community.docker.docker_container:
      name: "foo_db"
      image: "postgres:14.7"
      env:
        POSTGRES_PASSWORD=devops
        POSTGRES_USER=pete
        POSTGRES_DB=foo
      published_ports:
        - "0.0.0.0:5432:5432"
      volumes:
        - "/home/ubuntu/snapshot-prod-data.sql:/docker-entrypoint-initdb.d/init.sql"
  - name: Start foo_db container
    become: true
    command: sudo docker start foo_db
```

The inventories, those are the same with the all-servers-inventory, yet it excludes the all-server section

app_inventory.yml
``` yml
app_servers:
  hosts:
    app1:
      ansible_host: 
```
db_inventory.yml
``` yml
db_servers:
  hosts:
    db1:
      ansible_host:
```

The shell script execute commands from the root of the directory.

```sh
terraform -chdir=misc/ init
terraform -chdir=misc/ plan 
terraform -chdir=misc/ apply -auto-approve

#Run all severs playbook to install Docker for both server
ansible-playbook ./ansible/all_servers_playbook.yml -i ./ansible/all_servers_inventory.yml \
 --private-key ~/.ssh/id_rsa --ssh-extra-args="-o StrictHostKeyChecking=no"

#Run databasse playbook

ansible-playbook ./ansible/db_playbook.yml -i ./ansible/db_inventory.yml --private-key ~/.ssh/id_rsa 


#Run app playbook
ansible-playbook ./ansible/app_playbook.yml -i ./ansible/app_inventory.yml --private-key ~/.ssh/id_rsa 

```

For the ansible playbook commands, those require the RSA private key which is associated with the AWS, so that the code can connect to the EC2 then perform commands within the playbook files.


## Load Balancer Implementations:
Based on AlPine's requirements that they want to product to be more resillient that there must be another instance that host the foo_app container, and they should be separated from each other. Furtheremore, two of the instances must be deployed behind the Load Balancer with a database that runs another instance.  

Regarding the Load Balancer, it requires multiples components in order to properly operated. The components are VPC, Internet Gateway, Route Table, Subnets, Route Table Association, Load Balancer Target Group Attachment, Load Balancer Listener and Load balancer. Without any of the listed components the Load Balancer itself will cause problem when we try to connect to the application behind it. 

### VPC:
```tf
resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "foo app vpc"
  }
}
```

### Interet Gateway:

```tf
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "my-igw"
  }
}
```
The vpc_id will attach the VPC with VPC so that we can connect with the VPC

### Route Table
```tf
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}
```

### Subnets 

For the subnets I will create more than three so that later on the team can use it to implement more instances for their products, in this solution description I will only list one of them.

```tf
resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.8.0/22"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Public AZ2"
  }
  map_public_ip_on_launch = true
}
```
Each will have different avaiablility zone to ensure the flexibility for the application.

### Route Table Association
```tf
resource "aws_route_table_association" "public_2_rt_a" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_route_table.id
}
```

### Load Balancer Target Group Attachment

``` tf
resource "aws_lb_target_group_attachment" "app2" {
  target_group_arn = aws_lb_target_group.foo_app.arn
  target_id        = aws_instance.servers["app2"].id
  port             = 80
}
```

### Load Balancer Listener 
```tf
resource "aws_lb_listener" "foo_lb_listener" {
  load_balancer_arn = aws_lb.foo_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.foo_app.arn
  }
}
```
The listenee's port will be set the same as the port of the applications (foo_app) as will allow it to communicate with the database outside the Load Balancer

### Load balancer

```tf
resource "aws_lb" "foo_lb" {
  name               = "foolb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id]
  security_groups    = [aws_security_group.vms_for_app.id]
}
```
Finally the load balancer include the necessary infrastructures. It also include the security group of the application.

After completing the Load Balancer creation, I will now change the the security group of the database to the VPC security group, the example is below.

```tf
resource "aws_instance" "database" {
      ami             = data.aws_ami.ubuntu.id
      instance_type   = "t2.micro"
      key_name        = aws_key_pair.admin.key_name
      vpc_security_group_ids = [aws_security_group.vms_for_DB.id]
      tags = {
        Name = "foo db"
      }
}
```
After finishing create all the components for VPC, we will have this structure

<img src="/img/vpc.png" style="height:500px"/>


## S3 Bucket Bemote Back-End
For the remote Back-End, Alpine requires the terraform.tfstate file which will contains all the infrastructures of the application that has been generated during the terraform apply (deployment) process, to be locate on S3 bucket so that they secure their product information as well as stucures.

For achieve this I will create an extra misc folder contains a file called state-bucket-infra.tf which will initialize the local Back-End first

```tf
# state-bucket-infra.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "local" {}
}

resource "aws_dynamodb_table" "foo_state_bucket_table" {
  name           = "state_lock_table"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
resource "aws_s3_bucket" "foo_bucket" {
  bucket = "s3891667-state-bucket"
}
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.foo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
provider "aws" {
  region = "us-east-1"
  
}
```
While initial the local Back-End it will also create the requires components such as the DynamoDB table and the S3 bucket so that later on when we initial the remote back-end it will insert the state file into the bucket once the deployment process is completed. 

```tf
# main.tf

terraform {
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
      }
    }
    backend "s3" {
	bucket = "s3891667-state-bucket"
	key            = "terraform.tfstate"
	region         = "us-east-1"
	dynamodb_table = "state_lock_table"
	encrypt        = true
    }
}
```

## Github workflow

The final requirement from Alpine is to automate all the process using the Github workflow. 
For the security problems, I will use the Github Secret variables to store all the important value for AWS authentification as well as SSH key for AWS access used by Ansible commands

My cd-pipeline.yml contains 5 jobs

### Ansibile Setup:
This stage installs the Asnbile so the the virtual machine can run the Asible command for developement.

### AWS-CLi Setup:
Install the AWS CLI configure the credentials to connect to the EC2 instances.


### Artifacts check:
This will check the terraform.tfstate file exists in the s3 bucket by running AWS-CLI command, if the bucket returns the file name, the job will now terminate the deploy process by exit 1

```yml
    - uses: actions/checkout@v3
    - name: Set up AWS credentials
      run: |
        aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }} 
        aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws configure set aws_session_token ${{ secrets.AWS_SESSION_TOKEN }}
        aws configure set default.region us-east-1

    - name: Check artifact existence
      run: |
        if aws s3 ls s3://s3891667-state-bucket/terraform.tfstate | grep -q 'terraform.tfstate'; then
        echo "Artifact found. Skip deploy process."
        exit 1
        else
          echo "Artifact not found. Proceed with deploy process."
        fi
```

<img src="/img/artiCheck.png" style="height:200px"/>

### Terraform deploy:
This stage deploys the AWS infrastructure for the application then the Ansible playbook can connect to it and deploy the containners.

### Ansible Deploy: 
Finally, this will start the images for the database and the application.


### Github RestAPI:

Alpine also requires the workflow to not only be albe to trigger after main is changed, but also the RestAPI.

``` sh
curl -L \                                                
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <GithubAccountToken>"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/<RepoOwner>/<RepoName>/actions/workflows/<pipelineFile>/dispatches \
  -d '{"ref":"main","input":{"trigger_reasons":"TestingCD" }}'
```
This will trigger the workflow with just the shell command curl.

#### Example:

<img src="/img/restAPI.png" style="height:250px"/>



### Complete Application: 

<img src="/img/foo1.png" style="height:250px"/>
<img src="/img/foo2.png" style="height:250px"/>
<img src="/img/foo3.png" style="height:400px"/>
<img src="/img/foo4.png" style="height:500px"/>



### Diagram:

#### CD Diagram:

<img src="/img/cd.png" style="height:500px"/>


#### AWS Infrastructure Diagram:

<img src="/img/infra.png" style="height:500px"/>

