#!/bin/bash
# Script to initialize a testnet settings on a server

#Usage: terraform.sh <testnet_name> <testnet_node_number>

#Add kid node number for remote identification
echo "$2" > /etc/nodeid

