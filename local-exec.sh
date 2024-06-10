#!/bin/bash

host=$1

while true; do
    ssh-keyscan -t rsa $host >> ~/.ssh/known_hosts && break
    sleep 60
done