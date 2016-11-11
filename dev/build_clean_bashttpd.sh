#!/usr/bin/env bash
SOURCE_FILE=$1
TARGET_FILE=../bashttpd.sh

echo "" > $TARGET_FILE
while read -r _line; do
    egrep -v '(^[[:blank:]]*)(#|log_debug_text |LOG=|DEBUG=|$)' | sed 's/$_line//' >> $TARGET_FILE;
done < $SOURCE_FILE
