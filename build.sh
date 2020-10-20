#!/usr/bin/env bash

gem build dory.gemspec
sudo gem install *.gem
