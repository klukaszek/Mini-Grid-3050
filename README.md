# Mini-Grid
"Mini Grid" computer task management system (server) written in Bash.

This project could easily be repurposed using sockets instead of FIFOs to have an actual practical application across systems over LAN.

The main system must have `server.sh` running, and any other system (in this case it's another shell) has to make sure `jobSubmit.sh` is running.

Any tasks submitted by `jobSubmit.sh` will be run by a worker process that is spawned by the server. 

The number of total workers is based on the number of cores on the servers CPU.

## Program Design (Part of my assignment report)
My server can communicate with its workers and the submitJob script using N+1 FIFOs,
where N=number of cores. The server has its own FIFO to receive messages from the submitJob
script and the worker scripts, and every worker has its own FIFO to receive jobs from the server.
The server script must first be running before any jobs can be submitted using the submitJob
script to make sure that all FIFOs are initialized. When the server receives a job, it is added to a
job queue where the job waits for the next available worker using round-robin assignment. When
a worker is done waiting for its job to be complete, it writes “X ready” to the server FIFO, where
X=worker id. When the server FIFO receives an “X ready” message from a worker, the server
makes sure to set the current state of that worker to ready so a new job can be assigned to it once
it is that worker’s turn, and it also increments the total jobs completed by that worker by 1. I have
also made sure that the server cannot receive an “X ready” message from the submitJob script.
When the server receives a “status” (-s) message it prints the total number of workers, and it also
prints the total number of jobs processed by the worker that was handed the status job. So if
worker #3 receives the status job as its first job, the server will print, “# of workers: N, # of jobs
processed by worker 3: 0”, since the worker has not processed any previous jobs. When the
server receives a “shutdown” (-x) message, it checks the current status of every worker and sends
the shutdown message to workers who are not busy. Workers that are busy are immediately sent
a shutdown message once the server receives an “X ready” message from a busy worker. Once
the server receives a “shutdown” message, the existing job queue is ignored entirely and the
server tries to shut itself down along with all workers once none are busy. Upon shutdown, all
FIFOs are removed and every job is logged into a respective worker log file in /tmp.
