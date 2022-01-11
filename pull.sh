#!/bin/bash

set -eo pipefail

if [ ! -d legacy ]; then
  echo "legacy manifest doesn't exist, cloning..."
  git clone https://source.codeaurora.org/quic/la/platform/manifest -b release legacy
fi &

sleep 0.1
if [ ! -d system ]; then
  echo "system manifest doesn't exist, cloning..."
  git clone https://source.codeaurora.org/quic/la/la/system/manifest -b release system
fi &

sleep 0.1
if [ ! -d vendor ]; then
  echo "vendor manifest doesn't exist, cloning..."
  git clone https://source.codeaurora.org/quic/la/la/vendor/manifest -b release vendor
fi &

wait

for i in legacy system vendor; do
  cd $i
  (
    echo "Pulling updates from $i"
    git pull
    echo "Updated $i"
  ) &
  cd ..
done

wait
