#!/bin/bash
DATA_ROWS_MIN=$1
DATA_ROWS_MAX=$2

echo "Running from ${DATA_ROWS_MIN} to ${DATA_ROWS_MAX}"

MAPRED_EXAMPLES="/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.0.0.jar"

TERA_DIR="/tera/$DATA_ROWS"

TERA_INPUT_FILE="$TERA_DIR/input"
TERA_OUTPUT_FILE="$TERA_DIR/output"
TERA_REPORT_FILE="$TERA_DIR/report"

TERA_LOG_DIR=$HOME"~/experiment/logs"

mkdir -p "${TERA_LOG_DIR}"

yarn jar ${MAPRED_EXAMPLES} teragen $DATA_ROWS $TERA_INPUT_FILE &&
yarn jar ${MAPRED_EXAMPLES} terasort $TERA_INPUT_FILE $TERA_OUTPUT_FILE &&
yarn jar ${MAPRED_EXAMPLES} teravalidate $TERA_OUTPUT_FILE $TERA_REPORT_FILE

# Query history server for results
# wget something something
# Pipe into text file

# Delete the output and repeat
