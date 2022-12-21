#!/bin/bash
sudo snap install yq

yq --version

echo "alias yq='yq -C -P'" >> ~/.bashrc && source ~/.bashrc
