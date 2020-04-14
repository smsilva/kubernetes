#!/bin/bash

# System Update
apt-get update -y && \
apt-get upgrade -y && \
apt-get autoremove
