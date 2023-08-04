#!/bin/bash
#Deploy aws components using terraform with local backend
terraform -chdir=misc/ init
terraform -chdir=misc/ plan 
terraform -chdir=misc/ apply -auto-approve

#Deploy aws components using terraform with S3 remote backend
terraform -chdir=infra/ init  
terraform -chdir=infra/ plan 
terraform -chdir=infra/ apply -auto-approve

#Retrieving Output which are the public Ips
terraform_output=$(terraform -chdir=infra/ output 2>&1)
servers_ip=$(terraform  -chdir=infra/ output -json servers_ip | jq -r '.[]')
#database IP
db_ip=$(echo "$terraform_output" | grep -oP 'db_ip = "\K[^"]+')
#foo_app1 IP
app1_ip=$(echo "$servers_ip" | awk 'NR==1' | tr -d '"')
#foo_app2 IP
app2_ip=$(echo "$servers_ip" | awk 'NR==2' | tr -d '"')

inventory_file="./ansible"

#This section will write all the ips in ansible_host section in the playbook-inventory files 
sed -i "s/\(ansible_host:\s*\).*/\1$db_ip/" "$inventory_file/db_inventory.yml"


awk -v ip="$app1_ip" '/app1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"

awk -v ip="$app2_ip" '/app2:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"


awk -v ip="$db_ip" '/db1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"


awk -v ip="$app1_ip" '/app1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/app_inventory.yml" > "$inventory_file/app_inventory.yml.tmp" && mv "$inventory_file/app_inventory.yml.tmp" "$inventory_file/app_inventory.yml"

awk -v ip="$app2_ip" '/app2:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/app_inventory.yml" > "$inventory_file/app_inventory.yml.tmp" && mv "$inventory_file/app_inventory.yml.tmp" "$inventory_file/app_inventory.yml"

#Write public ip of databse in host name in app_playbook.yml
sed -i "s/\(DB_HOSTNAME=\).*/\1$db_ip/" "$inventory_file/app_playbook.yml"

#Run all severs playbook to install Docker for both server
ansible-playbook ./ansible/all_servers_playbook.yml -i ./ansible/all_servers_inventory.yml --private-key ~/.ssh/id_rsa --ssh-extra-args="-o StrictHostKeyChecking=no"

#Run databasse playbook

ansible-playbook ./ansible/db_playbook.yml -i ./ansible/db_inventory.yml --private-key ~/.ssh/id_rsa 


#Run app playbook
ansible-playbook ./ansible/app_playbook.yml -i ./ansible/app_inventory.yml --private-key ~/.ssh/id_rsa 
