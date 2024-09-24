#!/bin/bash

CONTAINER_NAME=""
SRC_PATH=""
DEST_PATH="/home/admin"
USER="admin"
GROUP="admin"

usage() {
    echo "USE: $0 -name <container_name> -src <source_path>"
    echo "  -name: name of container"
    echo "  -src: path to src folder/file"
    exit 1
}


while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -name)
        CONTAINER_NAME="$2"
        shift 2
        ;;
        -src)
        SRC_PATH="$2"
        shift 2
        ;;
        *)
        usage
        ;;
    esac
done


if [ -z "$CONTAINER_NAME" ] || [ -z "$SRC_PATH" ]; then
    usage
fi


SRC_NAME=$(basename "$SRC_PATH")
DEST_FULL_PATH="$DEST_PATH/$SRC_NAME"


echo "Copying $SRC_PATH to $CONTAINER_NAME:$DEST_FULL_PATH"
docker cp "$SRC_PATH" "$CONTAINER_NAME:$DEST_FULL_PATH"


echo "Changing ownership to $USER:$GROUP"
if [ -d "$SRC_PATH" ]; then

    docker exec -u 0 "$CONTAINER_NAME" find "$DEST_FULL_PATH" -type d -exec chown "$USER:$GROUP" {} +
    docker exec -u 0 "$CONTAINER_NAME" find "$DEST_FULL_PATH" -type f -exec chown "$USER:$GROUP" {} +
else

    docker exec -u 0 "$CONTAINER_NAME" chown "$USER:$GROUP" "$DEST_FULL_PATH"
fi

echo "Operation completed successfully"
