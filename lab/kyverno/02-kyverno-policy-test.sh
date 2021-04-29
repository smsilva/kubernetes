#!/bin/bash

kubectl apply -f ./policies/

kubectl create deployment nginx --image=nginx
