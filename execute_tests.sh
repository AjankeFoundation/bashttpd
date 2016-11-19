#!/usr/bin/env bash
error_count=0
for test_file in $(ls ./tests/*.bashtest); do	
    echo "running: \"${test_file}\""
    bashtest ${test_file} || let "error_count++"
    echo ""
done

if [[ "${error_count}" != "0" ]]; then
    echo "error count: ${error_count}"
    exit 1
else
    echo "'########:::::'###:::::'######:::'######::";
    echo " ##.... ##:::'## ##:::'##... ##:'##... ##:";
    echo " ##:::: ##::'##:. ##:: ##:::..:: ##:::..::";
    echo " ########::'##:::. ##:. ######::. ######::";
    echo " ##.....::: #########::..... ##::..... ##:";
    echo " ##:::::::: ##.... ##:'##::: ##:'##::: ##:";
    echo " ##:::::::: ##:::: ##:. ######::. ######::";
    echo "..:::::::::..:::::..:::......::::......:::";
    exit 0
fi
