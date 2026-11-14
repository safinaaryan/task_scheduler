#!/bin/bash
# ==========================================================
#  MINI TASK SCHEDULER  (inspired by github.com/purarue/evry)
#  Idea: a task runs only if enough time has passed since
#  the last time it ran. Every task can also have DO / DON'T
#  points that are shown right before it runs.
# ==========================================================

MODE="demo"     # "demo" = runs a ready-made example, "menu" = interactive menu

DATA_DIR="/tmp/mini_scheduler"
TASK_FILE="$DATA_DIR/tasks.txt"     # each line:  name|seconds|command
LAST_DIR="$DATA_DIR/last"           # one file per task, stores last run time
NOTE_DIR="$DATA_DIR/notes"          # one file per task, stores DO / DONT lines

# ---------- setup ----------
setup() {
    mkdir -p "$LAST_DIR" "$NOTE_DIR"
    touch "$TASK_FILE"
}

reset_all() {
    rm -rf "$DATA_DIR"
    setup
}

# ---------- helper functions ----------

# convert 30s / 5m / 2h / 1d into seconds (prints -1 if invalid)
to_seconds() {
    local value="${1%?}"        # everything except last character
    local unit="${1: -1}"       # last character
    unit=$(echo "$unit" | tr 'A-Z' 'a-z')   # make it lowercase
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "-1"
        return
    fi
    value=$((10#$value))        # 10# avoids octal problem with 08, 09
    case "$unit" in
        s) echo $((value)) ;;
        m) echo $((value * 60)) ;;
        h) echo $((value * 3600)) ;;
        d) echo $((value * 86400)) ;;
        *) echo "-1" ;;
    esac
}

# print seconds as "Xh Ym Zs"
format_time() {
    local s="$1"
    printf "%dh %dm %ds" $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

task_exists() {
    grep -q "^$1|" "$TASK_FILE"
}

# returns 0 (true) if the task is due, else 1.  Sets REMAINING (seconds left)
is_due() {
    local name="$1" secs="$2" last now elapsed
    REMAINING=0
    if [ ! -f "$LAST_DIR/$name" ]; then
        return 0                        # never ran before -> due
    fi
    last=$(cat "$LAST_DIR/$name")
    if ! [[ "$last" =~ ^[0-9]+$ ]]; then
        return 0
    fi
    now=$(date +%s)
    elapsed=$((now - last))
    if [ "$elapsed" -ge "$secs" ]; then
        return 0
    fi
    REMAINING=$((secs - elapsed))
    return 1
}

# ---------- main features ----------

# add_task <name> <every: 30s|5m|2h|1d> <command>
add_task() {
    local name="$1" every="$2" cmd="$3" secs
    if ! [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Error: task name can only have letters, numbers, - and _"
        return 1
    fi
    if task_exists "$name"; then
        echo "Error: task '$name' already exists"
        return 1
    fi
    secs=$(to_seconds "$every")
    if [ "$secs" -le 0 ]; then
        echo "Error: time '$every' is invalid. Use like 30s, 5m, 2h, 1d"
        return 1
    fi
    if [ -z "$cmd" ]; then
        echo "Error: command is empty"
        return 1
    fi
    echo "$name|$secs|$cmd" >> "$TASK_FILE"
    echo "Added task '$name' (runs every $(format_time "$secs"))"
}

# add_note <task name> <DO|DONT> <text>
add_note() {
    local name="$1" type="$2" text="$3"
    if ! task_exists "$name"; then
        echo "Error: task '$name' not found"
        return 1
    fi
    if [ "$type" != "DO" ] && [ "$type" != "DONT" ]; then
        echo "Error: type must be DO or DONT"
        return 1
    fi
    if [ -z "$text" ]; then
        echo "Error: note text is empty"
        return 1
    fi
    echo "$type|$text" >> "$NOTE_DIR/$name.txt"
    echo "Added $type point to '$name'"
}

# show_notes <task name>
show_notes() {
    local name="$1" type text
    if [ ! -s "$NOTE_DIR/$name.txt" ]; then
        echo "   (no DO / DON'T points for this task)"
        return
    fi
    while IFS='|' read -r type text; do
        if [ "$type" = "DO" ]; then
            echo "   [DO]    $text"
        elif [ "$type" = "DONT" ]; then
            echo "   [DON'T] $text"
        fi
    done < "$NOTE_DIR/$name.txt"
}

# list_tasks : show all tasks and their status
list_tasks() {
    local name secs cmd status
    echo "-------------- ALL TASKS --------------"
    if [ ! -s "$TASK_FILE" ]; then
        echo "No tasks yet."
        return
    fi
    while IFS='|' read -r name secs cmd; do
        [ -z "$name" ] && continue
        if is_due "$name" "$secs"; then
            status="DUE NOW"
        else
            status="wait $(format_time "$REMAINING")"
        fi
        echo "* $name | every $(format_time "$secs") | $status"
        show_notes "$name"
    done < "$TASK_FILE"
    echo "---------------------------------------"
}

# run_due : run every task whose time has come
run_due() {
    local name secs cmd
    echo "=== Checking tasks at $(date '+%H:%M:%S') ==="
    if [ ! -s "$TASK_FILE" ]; then
        echo "No tasks yet."
        return
    fi
    while IFS='|' read -r name secs cmd; do
        [ -z "$name" ] && continue
        if is_due "$name" "$secs"; then
            echo ">> Task '$name' is due. Remember:"
            show_notes "$name"
            # </dev/null so the command cannot eat the task file input
            if bash -c "$cmd" < /dev/null; then
                date +%s > "$LAST_DIR/$name"     # save time only on success
                echo "   Done. Time saved."
            else
                echo "   Command FAILED. Not saved, will retry next time."
            fi
        else
            echo ">> Skipping '$name' (next run in $(format_time "$REMAINING"))"
        fi
    done < "$TASK_FILE"
}

# remove_task <name>
remove_task() {
    local name="$1"
    if ! task_exists "$name"; then
        echo "Error: task '$name' not found"
        return 1
    fi
    grep -v "^$name|" "$TASK_FILE" > "$TASK_FILE.tmp"
    mv "$TASK_FILE.tmp" "$TASK_FILE"
    rm -f "$LAST_DIR/$name" "$NOTE_DIR/$name.txt"
    echo "Removed task '$name'"
}

# ---------- interactive menu ----------
menu() {
    local choice name every cmd type text more
    while true; do
        echo ""
        echo "====== MINI TASK SCHEDULER ======"
        echo "1. Add task"
        echo "2. Add DO / DON'T point to a task"
        echo "3. List tasks"
        echo "4. Run due tasks"
        echo "5. Remove task"
        echo "0. Exit"
        read -rp "Choose: " choice || break
        case "$choice" in
            1)
                while true; do
                    read -rp "Task name: " name
                    read -rp "Repeat every (e.g. 30s, 5m, 2h, 1d): " every
                    read -rp "Command to run: " cmd
                    add_task "$name" "$every" "$cmd"
                    read -rp "Add another task? (y/n): " more || break
                    if [ "$more" != "y" ] && [ "$more" != "Y" ]; then
                        break
                    fi
                done
                ;;
            2)
                read -rp "Task name: " name
                read -rp "Type (DO or DONT): " type
                read -rp "Point: " text
                add_note "$name" "$type" "$text"
                ;;
            3) list_tasks ;;
            4) run_due ;;
            5)
                read -rp "Task name: " name
                remove_task "$name"
                ;;
            0) echo "Bye!"; break ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

# ---------- demo (runs automatically) ----------
demo() {
    reset_all
    echo "##### STEP 1: add tasks #####"
    add_task study 5s "echo '   -> Studying Operating Systems...'"
    add_task water 1h "echo '   -> Drink a glass of water'"

    echo ""
    echo "##### STEP 2: add DO / DON'T points #####"
    add_note study DO "Sit at the desk and keep notes ready"
    add_note study DO "Study for 25 minutes, then take a break"
    add_note study DONT "Don't open social media"
    add_note study DONT "Don't keep the phone near you"
    add_note water DO "Use a full glass"
    add_note water DONT "Don't drink cold water right after exercise"

    echo ""
    echo "##### STEP 3: list tasks #####"
    list_tasks

    echo ""
    echo "##### STEP 4: run (both are due) #####"
    run_due

    echo ""
    echo "##### STEP 5: run again at once (both should be skipped) #####"
    run_due

    echo ""
    echo "##### STEP 6: wait 6 seconds, run again (only 'study' is due) #####"
    sleep 6
    run_due

    echo ""
    echo "##### STEP 7: remove a task #####"
    remove_task water
    list_tasks
}

# ---------- start ----------
setup
if [ "$MODE" = "menu" ]; then
    menu
else
    demo
fi
