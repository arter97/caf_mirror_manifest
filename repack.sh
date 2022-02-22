#!/bin/bash

#
# A script that tries to go through an Android tree and repacks Git objects
# to reduce its size by referencing mirrored objects.
#
# This script tries to match repositories to AOSP-style directory structure on
# the mirror.
#
# This must be executed after the tree is fully synced first.
#

set -eo pipefail

repack() {
  COUNT=$(cat $TMP | wc -l)

  if [[ "$COUNT" == "0" ]]; then
    return
  fi

  echo
  echo "Starting repacks on $COUNT repositories"
  echo

  while read repo ref; do
    cd "$repo"
    mkdir -p objects/info
    echo ${ref}/objects >> objects/info/alternates
    ( git repack -adl; echo; echo $repo done; echo ) &
    cd -
  done < $TMP

  wait
}

REPOUID="$(stat -c%u .repo)"
if [[ "$UID" != "$REPOUID" ]]; then
  echo "Running UID differs from .repo's UID, fixing"
  sleep 0.1
  exec sudo -u $(id -un $REPOUID) $0 $*
fi

MIRROR=/mirror
TMP=/tmp/$(uuidgen)
PASS=ce8f5104638b # random placeholder
PWD="$(pwd)"

echo "Working on $PWD"

find ${MIRROR}/aosp -type d -name '*.git' -prune -o -name '*.git' > $TMP.aosp
find ${MIRROR}/caf  -type d -name '*.git' -prune -o -name '*.git' > $TMP.caf
touch $TMP

if find .repo/manifests -name '*.xml' -exec cat {} + | grep LA.UM; then
  echo CAF detected
  PRIMARY=caf
  SECONDARY=aosp
else
  PRIMARY=aosp
  SECONDARY=caf
fi

# Check if the project is using mirror at all
if ! grep -q "reference = ${MIRROR}/${PRIMARY}" .repo/manifests.git/config || ! grep -q "${MIRROR}/${PRIMARY}" .repo/manifests.git/.repo_config.json; then
  echo "Project is not set to use mirror, fixing"
  echo repo init --reference=/mirror/$PRIMARY -m $(xmllint --xpath "string(//include/@name)" .repo/manifest.xml)
  repo init --reference=/mirror/$PRIMARY -m $(xmllint --xpath "string(//include/@name)" .repo/manifest.xml)
fi

# Manual match whitelist
REPLACE+="^build/make.git@platform/build.git "
REPLACE+="^art.git@platform/art.git "
REPLACE+="^external/json-c.git@platform/external/jsoncpp.git "
REPLACE+="^frameworks/hardware/interfaces.git@platform/hardware/interfaces.git "
REPLACE+="^hardware/interfaces.git@platform/hardware/interfaces.git "
REPLACE+="^prebuilts/build-tools.git@platform/prebuilts/build-tools.git "

# Some tricky CAF repositories
REPLACE+="^vendor/qcom/opensource/audio-hal/primary-hal.git@platform/hardware/qcom/audio.git "
REPLACE+="^vendor/qcom/opensource/commonsys-intf/display.git@platform/vendor/qcom-opensource/display-commonsys-intf.git "
REPLACE+="^vendor/qcom/opensource/commonsys-intf/bluetooth.git@platform/vendor/qcom-opensource/bluetooth-commonsys-intf.git "
REPLACE+="^vendor/qcom/opensource/@platform/vendor/qcom.opensource/ "

# These shouldn't match with anything
REPLACE+="^manifest.git@$PASS "
REPLACE+="^android.git@$PASS "

# Replace '-', '_' with '.' for relaxed grep search
REPLACE+="_@. "
REPLACE+="-@. "

( find * -type d -name .git; find * -type l -name .git ) | while read d; do
  if [ ! -e $d/objects/info/alternates ]; then
    # Find matching mirror
    tmp=$(echo "$d" | sed -e 's@/.git@.git@g')
    for i in $REPLACE; do
      tmp=$(echo "$tmp" | sed -e "s@$i@g")
    done
    if echo $tmp | grep -q $PASS; then
      continue
    fi

    if ! match=$(grep "/$tmp" $TMP.$PRIMARY); then
      if ! match=$(grep "/$tmp" $TMP.$SECONDARY); then
        # Retry by extracting projectname from .git/config
        if ! grep -q 'projectname = ' $d/config || ! match=$(grep "/$(cat $d/config | grep 'projectname =' | awk '{print $3}').git" $TMP.caf); then
          # Retry if it's a device/qcom repository with vendor/qcom
          if ! match=$(grep "/$(echo "$d" | sed -e 's@/.git@.git@g' -e 's@^device/qcom/@vendor/qcom/@g')" $TMP.caf); then
            echo No match for $d
            continue
          fi
        fi
      fi
    fi

    if [[ $match == *$'\n'* ]]; then
      echo "Multiple matches found, skipping: $d ($tmp) $match"
      continue
    fi

    echo $d $match >> $TMP
  fi
done

repack

rm $TMP
touch $TMP
# Find remaining Git repositories that weren't checked out
find .repo/project-objects -type d -name '*.git' | while read d; do
  if [ ! -e $d/objects/info/alternates ]; then
    tmp=$(echo "$d" | sed -e 's@.repo/project-objects/@@g')
    if ! match=$(grep "/$tmp" $TMP.$PRIMARY); then
      if ! match=$(grep "/$tmp" $TMP.$SECONDARY); then
        continue
      fi
    fi

    if [[ $match == *$'\n'* ]]; then
      echo "Multiple matches found, skipping: $d ($tmp) $match"
      continue
    fi

    echo $d $match >> $TMP

  fi
done

repack

rm ${TMP}*
