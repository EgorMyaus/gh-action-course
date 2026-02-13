#!/bin/bash

set -ueo pipefail

#environment
env=$1

#cucumber tag
tag=$2

#run cucumber tests & on failure run postcucumber
if ! yarn run cucumber:$env --profile $tag; then
  yarn run postcucumber;
  exit 1;
fi