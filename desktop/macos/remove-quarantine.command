#!/bin/sh
xattr -cr "$(dirname "$0")/wfm.app"
echo "wfm.app unquarantined, you can open it now"
