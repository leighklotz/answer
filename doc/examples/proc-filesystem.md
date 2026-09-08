```
klotz@nuc1:~👣$ (systype; ps gauxww)|help 'what is the cwd of the summarizer python process. output all its env vars'|tools 'file:read_anywhere=/proc/*'
🖥︎💬︎🤖📥/proc/1328/cwd🤖📥/proc/1328/environ✨
The current working directory (cwd) of the summarizer python process (PID 1328) is:
`/home/klotz/wip/summarizer-service/scripts`

Its environment variables are:
* SHELL=/bin/bash
* QT_ACCESSIBILITY=1
* SSH_AUTH_SOCK=/run/user/1000/gnupg/S.gpg-agent.ssh
* MEMORY_PRESSURE_WRITE=c29tZSAyMDAwMDAgMjAwMDAwMAA=
* GTK_MODULES=gail:atk-bridge
* PWD=/home/klotz/wip/summarizer-service/scripts
* LOGNAME=klotz
* SYSTEMD_EXEC_PID=1306
* HOME=/home/klotz
* LANG=en_US.UTF-8
* VIRTUAL_ENV=/home/klotz/wip/summarizer-service/scripts/.venv
* MEMORY_PRESSURE_WATCH=/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/summarizer-service.service/memory.pressure
* SECRET_KEY=xyzzy-redacted
* INVOCATION_ID=6ad32629570144bab15df449cf55feaa
* MANAGERPID=1236
* PYTHONPATH=/home/klotz/wip/summarizer-service
* USER=klotz
* SHLVL=1
* GSM_SKIP_SSH_AGENT_WORKAROUND=true
* VIRTUAL_ENV_PROMPT=(.venv)
* XDG_RUNTIME_DIR=/run/user/1000
* PS1=(.venv)
* JOURNAL_STREAM=8:14729
* XDG_DATA_DIRS=/usr/local/share/:/usr/share/:/var/lib/snapd/desktop
* PATH=/home/klotz/wip/answer/bin:/home/klotz/wip/summarizer-service/scripts/.venv/bin:/home/klotz/wip/summarizer-service/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
* DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
* OLDPWD=/home/klotz/wip/summarizer-service
* _=/home/klotz/wip/summarizer-service/scripts/.venv/bin/gunicorn
klotz@nuc1:~👣$
```
