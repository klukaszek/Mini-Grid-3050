#! /bin/bash

#variables
USER=yourname
SERVERFIFO=/tmp/server-$USER-inputfifo
workers=$(cat /proc/cpuinfo | grep processor | wc -l)
worker_statuses=()
worker_processed=()
tasks=()
id=1
shutdown=0
shutdown_count=0

#set umask before any file creation occurs
umask 0077

#handle shutdown and send shutdown message to workers. if worker is busy, wait until worker is ready before shutting it down. Delete server fifo.
shutdown_fn () {
    
    echo -e "\nBeginning shutdown process. Will wait for busy workers to be ready before ending."
    shutdown=1
    val=0
    #delete worker FIFOs and end processes by iterating through array of pids
    for status in ${worker_statuses[@]}; do

        val=$((val+1))
        WORKERFIFO=/tmp/worker-$USER-$val-inputfifo
        #if worker is ready then it should be shutdown and the FIFO should be removed
        if [[ $status -eq 0 ]]; then
            if [ -p "$WORKERFIFO" ] ; then 
                echo "shutting down worker $val and removing $WORKERFIFO"
                echo "-x" > $WORKERFIFO
                shutdown_count=$((shutdown_count+1))
            fi
        fi

    done

    #handle shutting down workers that are currently busy
    while [[ "$shutdown_count" -ne "$workers" ]];
    do
        #read from server fifo
        if read core task<$SERVERFIFO; then
            if [[ "$task" == "ready" ]]; then
                WORKERFIFO=/tmp/worker-$USER-$core-inputfifo
                if [ -p "$WORKERFIFO" ] ; then 
                    echo "shutting down worker $core and removing $WORKERFIFO"
                    echo "-x">$WORKERFIFO
                    shutdown_count=$((shutdown_count+1))
                fi
            fi
        fi
    done

    #remove server fifo
    rm $SERVERFIFO;
    echo -e "\nShutting down...";
    echo -e "\tremoving $SERVERFIFO";
}

#handle SIGINT
trap "{ 
    echo -e '\nTerminated by SIGINT'; 
    shutdown_fn;
    exit 1;  
    }" SIGINT

#initializes worker processes
create_workers_fn() {

    echo -e "Initializing $workers worker units...\n"
    val=1

    #initiate worker scripts
    while [[ "$val" -le "$workers" ]];
    do

        #assign current process and any child processes to specific core
        bash ./worker.sh $val -c &
        PID=$!
        echo "started worker: $PID"
        worker_statuses+=( 0 )
        worker_processed+=( 0 )
        val=$((val+1))

    done

}

#this is where the program basically starts

#check if server fifo is created
if [ ! -p "$SERVERFIFO" ] ; then 
    echo "making server fifo"
    mkfifo $SERVERFIFO
fi

#init workers
create_workers_fn
echo ""

while :;
do
    #update workerfifo var to have correct id
    WORKERFIFO=/tmp/worker-$USER-$id-inputfifo

    #check if there are tasks in queue
    if [[ ${#tasks[@]} -gt 0 ]]; then
        index=$((id-1))

        #if worker is available, give worker a task, set worker to busy, remove task from queue, and increment id to give next task to next worker
        if [[ ${worker_statuses[$index]} -eq 0 ]]; then

            #handle status request for worker
            if [[ "${tasks[0]}" == "status" ||  "${tasks[0]}" == "-s" ]]; then
                echo -e "# of workers: $workers\n# of jobs processed by worker $id: ${worker_processed[$index]}"
            fi

            #send task to worker
            echo ${tasks[0]} > $WORKERFIFO

            #sloppy method of removing first element of array, not very easy to do in bash
            tasks=("${tasks[@]:1}")
            #set worker to busy
            worker_statuses[$index]=1

            id=$((id+1))

            #set id to 1 if id > # workers
            if [[ "$id" -gt "$workers" ]]; then
                id=1
            fi

            c=${#tasks[@]}
            echo -e "task processed. tasks remaining in queue: $c\n"
        fi
    fi

    #if server fifo receives a messsage then...
    if read core task<$SERVERFIFO; then

        #handle tasks, this ignores core and is passed a dummy value of 1 from jobSubmit
        if [[ "$task" != "ready" ]]; then
            echo "server received "$task""

            #handle shutdown request and ignore all remaining tasks in queue
            if [[ "$task" == "-x"  ]]; then
                shutdown_fn
                break
            #add task to task queue
            else
                tasks+=( "$task" )
                c=${#tasks[@]}
                echo "tasks in queue: $c"
            fi
        
        #handle ready messages
        elif [[ "$task" == "ready" ]]; then
            #match beginning of string with digits in set then make sure the end matches the preceding quantifier
            regex='^[0-9]+$'
            
            #check if $core is a number and make sure value is in range of workers
            if [[ $core =~ $regex ]] && [[ "$core" -le "$workers" ]]; then
                i=$((core - 1))
                #check if worker is already ready
                if [[ "${worker_statuses[$i]}" -ne "0" ]]; then
                    worker_statuses[$i]=0
                    #increment number of tasks processed by worker
                    worker_processed[$i]=$((worker_processed[$i]+1))
                fi
            fi
        fi
    fi
done

exit 0
