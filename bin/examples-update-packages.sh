#!/bin/sh

set -eu

for project in examples/*; do
  if [ ! -f "$project/gleam.toml" ]; then
    continue
  fi

  echo "Updating dependencies for $project"
  cd "$project"
  gleam update
  gleam test || true
  cd ../..
done
