#!/bin/bash

set -eo pipefail

if [ ! -d legacy ]; then
  echo "legacy manifest doesn't exist, cloning..."
  git clone https://git.codelinaro.org/clo/la/platform/manifest -b release legacy
fi &

sleep 0.1
if [ ! -d system ]; then
  echo "system manifest doesn't exist, cloning..."
  git clone https://git.codelinaro.org/clo/la/la/system/manifest -b release system
fi &

sleep 0.1
if [ ! -d vendor ]; then
  echo "vendor manifest doesn't exist, cloning..."
  git clone https://git.codelinaro.org/clo/la/la/vendor/manifest -b release vendor
fi &

wait

# Switch to codelinaro.org if not done already
sed -i -e 's@source.codeaurora.org/quic@git.codelinaro.org/clo@g' */.git/config

for i in legacy system vendor; do
  cd $i
  (
    echo "Pulling updates from $i"
    git fetch --all
    git reset --hard origin/release
    echo "Updated $i"
  ) &
  cd ..
done

wait
