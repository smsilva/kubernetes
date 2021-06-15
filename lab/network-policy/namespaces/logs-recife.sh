#!/bin/bash
kubectl -n recife logs -f -l app=client
