#!/bin/bash
# This is intended to be run inside the docker container as the command of the docker-compose.

env

set -ex

bundle exec rspec spec && bundle exec rspec --tag integration -fd 2>/dev/null
