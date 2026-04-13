#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> [size in KB]+"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR=${OUTPUT_DIR:-out}
mkdir $OUTPUT_DIR > /dev/null 2>&1

shift

sizes=("$@")
echo "Cutting ${INPUT_FILE}:"
SKIP=0
for i in "${!sizes[@]}"; do
    OUTPUT_FILE="mtdblock$i"
    SIZE_KB="${sizes[$i]}"
    dd if="$INPUT_FILE" of="${OUTPUT_DIR}/$OUTPUT_FILE" bs=1024 count="$SIZE_KB" skip="$SKIP" 2>/dev/null
    echo "$OUTPUT_FILE $((SIZE_KB * 1024)) bytes"
    SKIP=$((SKIP + SIZE_KB))
done