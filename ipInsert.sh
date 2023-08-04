#!/bin/bash

#This is an extra file that replicate actions from  deployScript to use in the pipeline 

terraform -chdir=infra/  init 
terraform_output=$(terraform -chdir=infra/ output 2>&1)
servers_ip=$(terraform  -chdir=infra/ output -json servers_ip | jq -r '.[]')
db_ip=$(echo "$terraform_output" | grep -oP 'db_ip = "\K[^"]+')
app1_ip=$(echo "$servers_ip" | awk 'NR==1' | tr -d '"')
app2_ip=$(echo "$servers_ip" | awk 'NR==2' | tr -d '"')

inventory_file="./ansible"
sed -i "s/\(ansible_host:\s*\).*/\1$db_ip/" "$inventory_file/db_inventory.yml"



awk -v ip="$app1_ip" '/app1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"

awk -v ip="$app2_ip" '/app2:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"


awk -v ip="$db_ip" '/db1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/all_servers_inventory.yml" > "$inventory_file/all_servers_inventory.yml.tmp" && mv "$inventory_file/all_servers_inventory.yml.tmp" "$inventory_file/all_servers_inventory.yml"


awk -v ip="$app1_ip" '/app1:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/app_inventory.yml" > "$inventory_file/app_inventory.yml.tmp" && mv "$inventory_file/app_inventory.yml.tmp" "$inventory_file/app_inventory.yml"

awk -v ip="$app2_ip" '/app2:/{print $0; getline; $0 = "      ansible_host: \"" ip"\""} 1' "$inventory_file/app_inventory.yml" > "$inventory_file/app_inventory.yml.tmp" && mv "$inventory_file/app_inventory.yml.tmp" "$inventory_file/app_inventory.yml"

sed -i "s/\(DB_HOSTNAME=\).*/\1$db_ip/" "$inventory_file/app_playbook.yml"
