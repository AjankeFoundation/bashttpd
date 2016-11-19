#!/usr/bin/env bash

for test_file in $(ls ./tests/*.bashtest); do	
    bashtest ./tests/${test_file}
    sleep 5
done
