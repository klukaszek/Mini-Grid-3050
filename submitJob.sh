#! /bin/bash

#FIFO variables
USER=klukasze
SERVERFIFO=/tmp/server-$USER-inputfifo

#this is a placeholder since the server fifo reads id and line in the event it receives a "ready" message from a worker.
#a ready message can never be sent using SubmitJob
id=1

#get all command line arguments
line="$*"

#make sure server is running when SubmitJob.sh is started
if [[ ! -p "$SERVERFIFO" ]]; then 
    echo -e "Server is not currently running. Please start server.sh."
    exit 1
fi

#make sure submitJob is not trying to tell server that worker is ready
if [[ "$line" != *"ready"* ]]; then

    #pass any commands that are not empty
    if [[ "$line" = *[!\ ]* ]]; then
            echo $id $line > $SERVERFIFO
    fi
    
fi

exit 0