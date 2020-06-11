#!/bin/bash
if [ -z "${DOMAIN_NAME}" ]; then
  echo "You should source environment.conf first:"
  echo ""
  echo "  source environment.conf"
  echo ""

  exit 1
fi
