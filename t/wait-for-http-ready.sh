#!/usr/bin/env bash

#https://stackoverflow.com/a/50583452/2060502

attempt_counter=0
max_attempts=15

echo "Connecting to http://$1 .."

until $(curl --output /dev/null --silent --head http://$1); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi

    printf '.'
    attempt_counter=$(($attempt_counter+1))
    sleep 1
done

echo "Connected after $attempt_counter attempts"
