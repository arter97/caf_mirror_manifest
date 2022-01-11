#!/bin/bash

exec > /tmp/cafcron.log 2>&1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

set -eo pipefail

cd "$(dirname "$0")"

./pull.sh
./manifest.sh

git add .
git commit -sm "$(date "+%Y-%m-%d")"
git push

echo "CAF cronjob finished"
