#!/bin/bash
spin[0]="\\o\\"
spin[1]="|o|"
spin[2]="/o/"

for i in "${spin[@]}"
do
 printf "\b\b\b$i"
 sleep 0.2
done
