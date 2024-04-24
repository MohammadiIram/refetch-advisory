#!/usr/bin/env bash

# This script will invoke the re-fetch of all current Greenwave CVP gates.
#
# Usage:
# bash errata-refetch-greenwave.sh <ADVISORY_ID>

set -Eeuo pipefail

if ! klist >/dev/null 2>&1; then
  echo 'You need to have a valid Kerberos ticket. Use kinit first!' 1>&2
  exit 42
fi

if ! command -v elfinder >/dev/null 2>&1; then
  echo 'elfinder is missing. Install it with: sudo -i npm install elfinder -g' 1>&2
  exit 43
fi

if ! command -v jq >/dev/null 2>&1; then
  echo 'jq is missing. Install it with: sudo -i dnf install jq -y' 1>&2
  exit 44
fi

ADVISORY="${1:?Pass an Advisory ID as arg[1]!}"
LIST_ONLY="${LIST_ONLY:-false}"

html="$(mktemp -t advisory-XXXXX.html)"
function finish {
  rm -rf "$html"
}
trap finish EXIT

curl --silent --location --negotiate -u : \
  "https://errata.devel.redhat.com/advisory/${ADVISORY}/test_run/greenwave_cvp" \
  > "$html"

while read -r json; do
  if [[ "$(echo "$json" | jq -r '.status')" == 'foundMatch' ]]; then
    while read -r href; do
      url="https://errata.devel.redhat.com${href}"
      echo "Calling: ${url}"
      if [[ "false" == "${LIST_ONLY}" ]]; then
        curl -X POST --location --negotiate -u : "${url}" >/dev/null
      fi
    done < <(echo "$json" \
      | jq -r '.matchesDetails[].html' \
      | sed -En 's|^.+href="([^"]+)".+$|\1|p')
  fi
done < <(elfinder --selector 'table.external_test_runs_active a[href*=reschedule]' \
  --files "$html" \
  --json)
