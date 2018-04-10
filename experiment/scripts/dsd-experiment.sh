#!/bin/bash
set -exu
set -o pipefail

# Sync results to S3
HMAC-SHA256s(){
    KEY="$1"
    DATA="$2"
    shift 2
    printf "$DATA" | openssl dgst -binary -sha256 -hmac "$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}

HMAC-SHA256h(){
    KEY="$1"
    DATA="$2"
    shift 2
    printf "$DATA" | openssl dgst -binary -sha256 -mac HMAC -macopt "hexkey:$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}

# Args:
# File to upload path
# Name to upload as
S3Upload(){
    AWS_SECRET_KEY=$AWS_SECRET
    AWS_ACCESS_KEY=$AWS_ACCESS

    FILE_TO_UPLOAD=$1
    BUCKET="sc14jb"
    STARTS_WITH="dsd/${DATA_ROWS}/$2"

    REQUEST_TIME=$(date +"%Y%m%dT%H%M%SZ")
    REQUEST_REGION="eu-west-2"
    REQUEST_SERVICE="s3"
    REQUEST_DATE=$(printf "${REQUEST_TIME}" | cut -c 1-8)
    AWS4SECRET="AWS4"$AWS_SECRET_KEY
    ALGORITHM="AWS4-HMAC-SHA256"
    EXPIRE="2018-06-01T00:00:00.000Z"
    ACL="private"

    POST_POLICY='{"expiration":"'$EXPIRE'","conditions": [{"bucket":"'$BUCKET'" },{"acl":"'$ACL'" },["starts-with", "$key", "'$STARTS_WITH'"],["eq", "$Content-Type", "application/octet-stream"],{"x-amz-credential":"'$AWS_ACCESS_KEY'/'$REQUEST_DATE'/'$REQUEST_REGION'/'$REQUEST_SERVICE'/aws4_request"},{"x-amz-algorithm":"'$ALGORITHM'"},{"x-amz-date":"'$REQUEST_TIME'"}]}'

    UPLOAD_REQUEST=$(printf "$POST_POLICY" | openssl base64 )
    UPLOAD_REQUEST=$(echo -en $UPLOAD_REQUEST |  sed "s/ //g")

    SIGNATURE=$(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256s $AWS4SECRET $REQUEST_DATE ) $REQUEST_REGION) $REQUEST_SERVICE) "aws4_request") $UPLOAD_REQUEST)

    curl --silent \
        -F "key=""$STARTS_WITH" \
        -F "acl="$ACL"" \
        -F "Content-Type="application/octet-stream"" \
        -F "x-amz-algorithm="$ALGORITHM"" \
        -F "x-amz-credential="$AWS_ACCESS_KEY/$REQUEST_DATE/$REQUEST_REGION/$REQUEST_SERVICE/aws4_request"" \
        -F "x-amz-date="$REQUEST_TIME"" \
        -F "Policy="$UPLOAD_REQUEST"" \
        -F "X-Amz-Signature="$SIGNATURE"" \
        -F "file=@"$FILE_TO_UPLOAD http://$BUCKET.s3.$REQUEST_REGION.amazonaws.com/
}

MainExperiment(){
    DATA_ROWS=$1
    ITERATION=$2
    
    echo "Cleaning hdfs..."
    hdfs dfs -rm -r -f -skipTrash /tera


    MAPRED_EXAMPLES="/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.0.0.jar"

    TERA_DIR="/tera/$DATA_ROWS/"

    TERA_INPUT_FILE="${TERA_DIR}input"
    TERA_OUTPUT_FILE="${TERA_DIR}output"
    TERA_REPORT_FILE="${TERA_DIR}report"

    TERA_LOG_DIR="${HOME}experiment/logs/${DATA_ROWS}-${ITERATION}/"
    TERA_LOGFILE="${TERA_LOG_DIR}log.txt"

    TIMING_FILE="${TERA_LOG_DIR}timing.json"
    COUNTERS_FILE="${TERA_LOG_DIR}counters.json"

    mkdir -p "${TERA_LOG_DIR}"

    echo "Running with ${DATA_ROWS} rows, iteration ${ITERATION}"
    yarn jar ${MAPRED_EXAMPLES} teragen "$DATA_ROWS" "$TERA_INPUT_FILE" &&
    yarn jar ${MAPRED_EXAMPLES} terasort "$TERA_INPUT_FILE" "$TERA_OUTPUT_FILE" |& tee -a "$TERA_LOGFILE" &&
    yarn jar ${MAPRED_EXAMPLES} teravalidate "$TERA_OUTPUT_FILE" "$TERA_REPORT_FILE"

    # Get the job id from the log file
    JOB_ID=$(grep -Eo -m 1 'job_(\d){13}_(\d)+' < "$TERA_LOGFILE")

    # Query history server for results
    JOBHISTORY_URL="http://historyserver:19888/ws/v1/history/mapreduce/jobs/${JOB_ID}"

    echo "Collecting JobHistory results"
    curl "${JOBHISTORY_URL}" -o "$TIMING_FILE"
    curl "${JOBHISTORY_URL}/counters" -o "$COUNTERS_FILE"

    S3Upload "$TIMING_FILE" "${ITERATION}-timing.json"
    S3Upload "$COUNTERS_FILE" "${ITERATION}-counters.json"
    S3Upload "$TERA_LOGFILE" "${ITERATION}-log.txt"
}

ITER=$1

shift
declare -a ROWS
ROWS=("$@")

for r in "${ROWS[@]}";
do
    for i in $(seq 1 "$ITER");
    do
        MainExperiment "$r" "$i"
    done
done
