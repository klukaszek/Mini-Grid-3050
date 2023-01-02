# Mini-Grid
"Mini Grid" computer task management system (server) written in Bash.

This project could easily be repurposed using sockets instead of FIFOs to have an actual practical application across systems over LAN.

The main system must have `server.sh` running, and any other system (in this case it's another shell) has to make sure `jobSubmit.sh` is running.

Any tasks submitted by `jobSubmit.sh` will be run by a worker process that is spawned by the server. 

The number of total workers is based on the number of cores on the servers CPU.
