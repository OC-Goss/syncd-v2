# syncd-v2
Syncs files between your local PC and minecraft OC computer.

This is a socket-based version of OpenComputers syncing daemon to hopefully fix issues that arose during the development of HTTP-based version (missing keystrokes in terminal due to the polling nature of the solution and only one OC computer being able to sync files).

### Currently WIP
Protocol and the daemon iteself are still being worked on. For now the setup is aiming to be identical to the first version, i.e. you'll need to have a public IP and set up port forwarding so your OC computer can connect to the server running on your local machine (with the possible extension of proxying that through a masterserver which will forward messages between client and server, so no public IP and port forwarding will be needed on the user side). Syncing of multiple directories not necessarily in the same top-level directory will also be supported. For now, only one-way sync is planned to be implemented, i.e. from the local PC to minecraft OC computer, with a possible extension of two-way sync.
