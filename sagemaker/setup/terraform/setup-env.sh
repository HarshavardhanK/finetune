#!/bin/bash

#Read the .env file and export the variables
export $(grep -v '^#' ../../.env | xargs)

#Run terraform with the environment variables
terraform "$@" 