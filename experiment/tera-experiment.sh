#!/bin/bash
DATA_ROWS=$1

TERA_DIR="/tera/$DATA_ROWS"

TERA_INPUT_FILE="$TERA_DIR/input"
TERA_OUTPUT_FILE="$TERA_DIR/output"
TERA_REPORT_FILE="$TERA_DIR/report"

TERA_LOG_DIR=$HOME"experiment/logs"

yarn jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce\-examples-3.0.0.jar teragen $DATA_ROWS $TERA_INPUT_FILE &&
yarn jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce\-examples-3.0.0.jar terasort $TERA_INPUT_FILE $TERA_OUTPUT_FILE &&
yarn jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce\-examples-3.0.0.jar teravalidate $TERA_OUTPUT_FILE $TERA_REPORT_FILE
