#!/bin/bash
kubectl -n olinda logs -f -l app=client
