#!/usr/bin/env bash
SOURCE_FILE=$1
TARGET_FILE=../bashttpd.sh

head -n 1 $SOURCE_FILE > $TARGET_FILE
while read -r _file_line; do
    egrep -v '(^[[:blank:]]*)(#|log_debug_text |LOG=|DEBUG=|$)' | sed 's/$_file_line//' >> $TARGET_FILE;
done < <(tail -n +1 $SOURCE_FILE)
