#!/bin/bash

now=$(date -u +%+4Y%m%d%H%M%S)
file="./migrations/${now}_$1.sql"
touch $file
echo "Created $file"

