#!/bin/bash
VERSION="0.6.2"

TAR_FILE="ytop-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"

wget "https://github.com/cjbassi/ytop/releases/download/${VERSION}/${TAR_FILE}"

tar xvf "${TAR_FILE}" && \
mv ytop /usr/bin/ && \
rm "${TAR_FILE}"
