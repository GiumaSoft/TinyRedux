#!/bin/zsh

rm -rf *.xcworkspace
find ./Projects/ -name "*.xcodeproj" | xargs rm -rf

tuist generate
