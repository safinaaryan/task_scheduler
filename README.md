# Mini Task Scheduler (Bash)

A small task scheduler written in pure Bash.

**Core idea:** a task runs only if enough time has passed since the last time it ran.
The last run time is saved in a small file for every task.

## Features
- Add one or many tasks with a repeat time (`30s`, `5m`, `2h`, `1d`) and a command
- Add **DO** and **DON'T** points to each task (shown right before the task runs)
- List all tasks with status (`DUE NOW` or time left to wait)
- Run only the tasks that are due
- Remove a task
- If a command fails, its time is not saved, so it retries next time
- No installation needed, works in any online Bash shell

## How to run

**Online Bash compiler (OnlineGDB, JDoodle, Programiz, ...)**
1. Select Bash, paste the contents of `scheduler.sh`, press Run.
2. By default it runs a demo (`MODE="demo"`).
3. For the interactive menu change it to `MODE="menu"` and type answers in the input box, one per line.

**Linux / macOS / WSL**
```bash
bash scheduler.sh
```

## Menu input example
```
1
GYM
1d
echo GO TO GYM
y
STUDY
2h
echo STUDY OS
n
2
GYM
DO
Warm up first
3
4
0
```

## Project files
| File | Purpose |
|---|---|
| `scheduler.sh` | the whole scheduler |
| `README.md` | this file |

## Data location
Data is stored in `/tmp/mini_scheduler` (`tasks.txt`, `last/`, `notes/`).
Some online compilers delete `/tmp` after each run.

## Concepts used
Bash functions, `case`, loops, `read`, file handling, `grep`, `date +%s` (timestamps), exit codes.

## Credit
Idea from [evry](https://github.com/purarue/evry) by purarue (Apache-2.0). This is an independent, simplified Bash version written for learning.
