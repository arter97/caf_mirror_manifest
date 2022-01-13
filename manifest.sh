#!/bin/bash

set -eo pipefail

MANIFEST=default.xml

echo "Generating $MANIFEST ..."

# Header
cat << EOF > "$MANIFEST"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote fetch="git://codeaurora.org/quic/la" name="caf"/>
  <default remote="caf" revision="master"/>

EOF

CPUS=$(nproc --all)
TMP=/tmp/$(uuidgen).caf

# Extract all "name=" values from LA.UM and QSSI targets
# This will take a while as it has to read gigabytes of XML files and sort them
# Use GNU parallel to divide the load to multiple CPU cores
grep -l codeaurora.org/quic/la */*LA.UM*.xml */*QSSI*.xml | parallel -N $CPUS "cat {} | grep '<project ' | sed -e 's@\"/@\" @g' -e 's@\">@\" @g' | tr ' ' '\n' | grep name= | sort | uniq" | sort | uniq > $TMP

# Remove faulty repositories from blacklist.txt
while read line; do
  sed -i -e "/$(echo ${line} | sed -e 's@/@\\/@g')/d" $TMP
done < blacklist.txt

# Fix "name=" values to proper XML format
cat $TMP | while read line; do
  echo "  <project ${line}/>"
done >> "$MANIFEST"

# Footer
cat << EOF >> "$MANIFEST"

</manifest>
EOF

# Remove temp file
rm $TMP
