#!/bin/bash

# This script helps to manage general git tasks

HL='\033[1;33m'  # yellow
ERR='\033[0;31m' # red
HOK='\033[1;32m' # green
NC='\033[0m'     # no colour
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

SERVICES_DIR="${HOME}/dev"

function show_usage() {
    #  bash completion parses this output
    echo -e "Usage: $(basename $0) <command> [arguments]"
    echo -e "<command> is one of:"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "check"           "check whether any of repo is not clean and/or has stashed changes"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "update"          "update branch 'live' in all repos"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "status"          "show git status for all repos"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "reset"           "checkout branch 'live' in all repos"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "branches"        "list branches from current repo"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "find <task>"     "find repos with branch of given task ID"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "checkout <task>" "checkout branch for task '<task>' in all repos"
    printf "  - ${BOLD}%-15s${NORMAL} - %s\n" "delete <task>"   "delete branch for task '<task>' in all repos"
}

function command_branches() {
    git rev-parse 2>/dev/null

    if [ $? == 0 ] ; then
        git branch -vv | awk '{
            if ($1 == "*") {
              branch = sprintf("* \033[2;32m%s\033[0m", $2)
              parent = $4
            }
            else {
              branch = gensub(/-([0-9]{6})-/, "-\033[1;34m\\1\033[0m-", "g", $1)
              parent = $3
            }

            printf "%70s ← \033[1;33m %s \033[0m\n",
              branch,
              substr(parent, 2, length(parent) - 2)
        }'
    else
        echo "Not a git repository"
    fi
}

function command_status() {
    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            branch=$(git status | awk '/On branch/ {print $NF}')
            branch_info=$(git status | awk '/Your branch/ {print $0}')
            echo -e "${HL}${service}${NC}"
            echo -e "    $branch"
            echo -e "    $branch_info"
        fi

        cd ..
    done
}

function command_check() {
    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            clean=$(git status | grep "nothing to commit, working directory clean")

            if [ -z "$clean" ] ; then
                echo -e "${ERR}${service} is not clean${NC}"
            fi

            stashes=$(git --no-pager stash list)

            if [ ! -z "$stashes" ] ; then
                echo -e "${ERR}${service} has stashed changes${NC}"
                git --no-pager stash list
            fi
        fi

        cd ..
    done
}

function command_update() {
    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            clean=$(git status | grep "nothing to commit, working directory clean")

            if [ ! -z "$clean" ] ; then
                git checkout live
                git remote update
                git remote prune origin
                git pull origin live
            else
                echo -e "${ERR}${service} is not clean${NC}"
            fi
        fi

        cd ..
    done
}

function command_find() {
    task="$1"

    if [ -z "$task" ] ; then
        show_usage
        exit 1
    fi

    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            branch=$(git branch --list *${task}* | awk '{print $NF}')

            if [ ! -z "${branch}" ] ; then
                printf "%-20s %s\n" ${service} ${branch}
            fi
        fi

        cd ..
    done
}

function command_checkout() {
    task="$1"

    if [ -z "$task" ] ; then
        show_usage
        exit 1
    fi

    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            clean=$(git status | grep "nothing to commit, working directory clean")

            if [ ! -z "$clean" ] ; then
                branch_cnt=$(git branch --list *${task}* | wc -l)
                branch=$(git branch --list *${task}* | tail -n 1 | awk '{print $NF}')

                if [ ! -z "$branch" ] ; then
                    echo -e "${HL}$service${NC}"

                    if (( branch_cnt > 1 )) ; then
                        echo -e "${ERR}${BOLD}Multiple branches exist, switching to the most recent one${NORMAL}${NC}"
                    fi

                    git checkout $branch
                fi
            else
                echo -e "${ERR}${service} is not clean${NC}"
            fi
        fi

        cd ..
    done
}

function command_delete() {
    task="$1"

    if [ -z "$task" ] ; then
        show_usage
        exit 1
    fi

    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            branch_cnt=$(git branch --list *${task}* | wc -l)
            branch=$(git branch --list *${task}* | tail -n 1 | awk '{print $NF}')

            if [ ! -z "$branch" ] ; then
                echo -e "${HL}$service${NC}"

                if (( branch_cnt > 1 )) ; then
                    echo -e "${ERR}${BOLD}Multiple branches exist, please remove manually${NORMAL}${NC}"
                elif (( branch_cnt == 1 )) ; then
                    git branch -d $branch
                fi
            fi
        fi

        cd ..
    done
}

function command_reset() {
    for service in ${SERVICES[@]} ; do
        cd "${SERVICES_DIR}/${service}"
        git rev-parse 2>/dev/null

        if [ $? == 0 ] ; then
            clean=$(git status | grep "nothing to commit, working directory clean")

            if [ ! -z "$clean" ] ; then
                echo -e "${HL}$service${NC}"
                git checkout live
            else
                echo -e "${ERR}${service} is not clean${NC}"
            fi
        fi

        cd ..
    done
}

if [ -z "$1" ] ; then
    show_usage
    exit 1
fi

if [ ! -d "$SERVICES_DIR" ] ; then
    echo -e "${ERR}Services directory ${SERVICES_DIR} not found"
    exit 1
fi

SERVICES=$(ls -1 $SERVICES_DIR | grep ^psp_)

if [ ${#SERVICES[@]} == 0 ] ; then
    echo -e "${ERR}No repos found${NC}"
    exit 1
fi

case $1 in
    "status")
        command_status
        ;;
    "branches")
        command_branches
        ;;
    "update")
        command_update
        ;;
    "reset")
        command_reset
        ;;
    "find")
        command_find $2
        ;;
    "check")
        command_check
        ;;
    "checkout")
        command_checkout $2
        ;;
    "delete")
        command_delete $2
        ;;
    *)
        show_usage
        ;;
esac
