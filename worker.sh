#! /bin/bash

#pass worker process its worker id
id=$1

USER=yourname
SERVERFIFO=/tmp/server-$USER-inputfifo
WORKERFIFO=/tmp/worker-$USER-$id-inputfifo
WORKERLOG=/tmp/worker-$USER.${id}.log
PID=$$
CORE=$(($id-1))

#set umask before any file creation occurs
umask 0077

#make sure server is running when jobSubmit.sh is started
if [[ ! -p "$SERVERFIFO" ]]; then 
    echo -e "Server is not currently running. Please start server.sh\nExiting..."
    exit 1
fi

#create worker fifo
if [[ ! -p "$WORKERFIFO" ]]; then 
    mkfifo $WORKERFIFO
fi

#create worker log file for specific worker id
cat > $WORKERLOG

#assign current process and any child processes to specific core 
#hide output from command by redirecting output to /dev/null
taskset -cp $CORE $PID > /dev/null

exec &2>&1

#loop infinitely until server kills this process with SIGSTOP
while :;
do

    if read line<$WORKERFIFO; then

        #print worker id and command to STDOUT
        echo "worker $id received: $line"

        if [[ $line == "-x" ]]; then
            echo "shutting down worker..."
            break
        elif [[ $line == "status" || $line == "-s" ]]; then
            echo "printing worker status to server..."
        elif [[ "$line" == *">"*  ]]; then #this handles simple output redirection (ex. echo "hello" \> file.txt)
            first=${line%">"*} #get substring before redirection using parameter expansion
            last=${line#*">"} #get substring after redirection using parameter expansion

            $first > $last &
        elif [[ "$line" == *"<"* ]]; then #this handles simple input redirection (ex. sort \< file.txt)
            first=${line%"<"*} #get substring before redirection using parameter expansion
            last=${line#*"<"} #get substring after redirection using parameter expansion

            $first < $last &
        elif [[ "$line" == *"|"* ]]; then #this handles simple piping (ex. cat file.txt \| sort)
            first=${line%"|"*} #get substring before pipe using parameter expansion
            last=${line#*"|"} #get substring after pipe using parameter expansion

            $first | $last &
        else
            #make sure to redirect STDERR to STDOUT in case the command is not recognized by bash
            $line &
        fi
        
        wait; echo $id "ready" > $SERVERFIFO
        
    fi

done > $WORKERLOG

exec &2>&-

#remove worker fifo when worker exits
rm $WORKERFIFO

exit 0
