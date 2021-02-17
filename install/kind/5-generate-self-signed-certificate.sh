#!/bin/bash
openssl req -x509 \
  -newkey rsa:4096 \
  -nodes \
  -keyout cert.key.pem \
  -out cert.pem \
  -days 365 \
  -subj '/CN=app.example.com'
