#!/bin/bash

# Replaces the image UUIDs in all the deployable samples.

if [ "x$1" == "x" ]; then
  echo "Usage: $0 NEW_UUID"
  exit 1
fi
uuid="$1"
replace_cmd="s/<image id=.*\/>/<image id=\"$uuid\"\/>/g"
sed -i "$replace_cmd" *.xml
