ssh-add
=======

rel: 8f34a17

This runs as a user service to initialise the ssh-agent with my private key on login. This helps with `git-bug`, which requires the ssh agent to be configured instead of falling back to the private key file.
