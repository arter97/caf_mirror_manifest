#!/bin/bash

set -eo pipefail

MANIFEST=default.xml

echo "Generating $MANIFEST ..."

# Header
cat << EOF > "$MANIFEST"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote fetch="https://git.codelinaro.org/clo/la" name="caf"/>
  <default remote="caf" revision="master"/>

EOF

CPUS=$(nproc --all)
TMP=/tmp/$(uuidgen).caf

# Extract all "name=" values from LA.UM and QSSI targets
# This will take a while as it has to read gigabytes of XML files and sort them
# Use GNU parallel to divide the load to multiple CPU cores
grep -l /la */*LA.UM*.xml */*QSSI*.xml | parallel -N $CPUS "cat {} | grep '<project ' | sed -e 's@\"/@\" @g' -e 's@\">@\" @g' -e 's@\.git@@g' | tr ' ' '\n' | grep name= | sort | uniq" | sort | uniq > $TMP

# Remove faulty repositories from blacklist.txt
while read line; do
  sed -i -e "/$(echo ${line} | sed -e 's@/@\\/@g')/d" $TMP
done < blacklist.txt

# Remove repositories that are replaced with '_repo' ones
grep '_repo"' $TMP | sed 's/_repo//g' > $TMP.repo
cat $TMP.repo | while read line; do
  grep -v "$line" < $TMP > $TMP.2
  mv $TMP.2 $TMP
done

# Fix "name=" values to proper XML format
cat $TMP | while read line; do
  echo "  <project ${line}/>"
done >> "$MANIFEST"

# Footer
cat << EOF >> "$MANIFEST"

</manifest>
EOF

# Remove temp file
rm ${TMP}*
