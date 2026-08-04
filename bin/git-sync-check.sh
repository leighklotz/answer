#!/bin/bash

# simple example of a wrapper or command
ask 'Perform a sync check: run `git fetch`, 
     then show me my current status compared to origin/main, 
     and finally list any commits I am holding back locally using `git log --oneline`.' | tools git

