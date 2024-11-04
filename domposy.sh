#!/bin/bash

# DESCRIPTION:
# This script simplifies your Docker Compose management.

ENABLE_ADVANCED_LOGGING=false
ENABLE_DEBUG_LOGGING=false

LOG_FILE_PATH="/tmp"

# # # # # # # # # # # #|# # # # # # # # # # # #
#              SCRIPT INFORMATION             #
# # # # # # # # # # # #|# # # # # # # # # # # #

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SCRIPT_NAME="$0"
SIMPLE_SCRIPT_NAME=$(basename "$SCRIPT_NAME")
SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION="${SIMPLE_SCRIPT_NAME%.*}"

# # # # # # # # # # # #|# # # # # # # # # # # #
#              LOGGING DIRECTORIES            #
# # # # # # # # # # # #|# # # # # # # # # # # #

LOG_DIR="${LOG_FILE_PATH}/${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_logs/"
LOG_FILE="$(date +"%Y-%m-%d_%H-%M-%S")_log_${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}.txt"
LOG_FILE_WITH_LOG_DIR="${LOG_DIR}${LOG_FILE}"

# # # # # # # # # # # #|# # # # # # # # # # # #
#             LOGGING FUNCTIONALITY           #
# # # # # # # # # # # #|# # # # # # # # # # # #

log() {
    local level="$1"
    local message="$2"

    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi

    local script_info=""
    if [ "$ENABLE_ADVANCED_LOGGING" = true ]; then
        script_info=" ($SIMPLE_SCRIPT_NAME)"
    fi

    if [[ -n "$message" ]]; then
        while IFS= read -r line; do
            echo "$(date +"%d.%m.%Y %H:%M:%S") - $level - $line" >>"$LOG_FILE_WITH_LOG_DIR"
            echo "  $level$script_info - $line"
        done <<<"$message"
    fi
}

log_debug() {
    if [ "$ENABLE_DEBUG_LOGGING" = true ]; then
        log "DEBUG  " "$1"
    fi
}

log_cmd() {
    log "CMD    " "$1"
}

log_dry_run() {
    log "DRY-RUN" "Dry run is enabled. Skipping '$1'"
}

log_info() {
    log "INFO   " "$1"
}

log_warning() {
    log "WARNING" "$1"
}

show_log_file() {
    if [[ -f "$LOG_FILE_WITH_LOG_DIR" ]]; then
        log_info "Log file: '${LOG_FILE_WITH_LOG_DIR}'"
    else
        echo "E R R O R - Log file creation failed: '${LOG_FILE_WITH_LOG_DIR}' - E R R O R"
    fi
}

log_error() {
    log "ERROR  " "$1"

    show_log_file
    exit 1
}

# # # # # # # # # # # #|# # # # # # # # # # # #
#                 PREPARATIONS                #
# # # # # # # # # # # #|# # # # # # # # # # # #

# Checks whether the user has root rights and if not, whether he is at least added to the 'docker' group.
check_permissions() {
    log_info "Current user: '$(whoami)'"
    if [[ $(id -u) -ne 0 ]]; then
        if groups $(whoami) | grep -q '\bdocker\b'; then
            log_warning "You do not have root rights. If you want to create backups, they may not work properly."
        else
            log_error "You need to be either a member of the 'docker' group or have root privileges to run this script."
        fi
    fi
}

# Returns the Docker Compose command. So whether 'docker-compose' or 'docker compose'.
get_docker_compose_command() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        log_error "Neither 'docker-compose' nor 'docker compose' command found. Is it installed?"
    fi
}

# Validates whether the docker compose command can also be executed by determining the version.
validate_docker_compose_command() {
    local version_output="$($DOCKER_COMPOSE_CMD version 2>&1)"

    if [[ $? -ne 0 ]]; then
        log_error "Failed to execute '$DOCKER_COMPOSE_CMD version'. Error: $version_output"
    fi
    log_cmd "$version_output"
}

check_permissions

DOCKER_COMPOSE_NAME="docker-compose" # Name for Docker Compose files and path components

DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
log_debug "'${DOCKER_COMPOSE_CMD}' is used"
validate_docker_compose_command

# # # # # # # # # # # #|# # # # # # # # # # # #
#                   GETOPTS                   #
# # # # # # # # # # # #|# # # # # # # # # # # #

DEFAULT_ACTION="backup"
DEFAULT_SEARCH_DIR="/home/"
DEFAULT_BACKUP_DIR="/tmp/${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_backups/"
DEFAULT_EXCLUDE_DIR="tmp"

ACTION="${DEFAULT_ACTION}"
SEARCH_DIR="${DEFAULT_SEARCH_DIR}"
BACKUP_DIR="${DEFAULT_BACKUP_DIR}"
EXCLUDE_DIR="${DEFAULT_EXCLUDE_DIR}"

ENABLE_DRY_RUN=false
ENABLE_CLEANUP=false

while getopts ":hdna:s:b:e:c" opt; do
    case ${opt} in
    h)
        echo "It is recommended to run the script with root rights to ensure that the backups work properly."
        echo
        echo "Usage: (sudo) $SCRIPT_NAME [-h] [-d] [-n] [-a ACTION] [-s SEARCH_DIR] [-b BACKUP_DIR] [-e EXCLUDE_DIR] [-c]"
        echo "  -h                 Show help"
        echo "  -d                 Enables debug logging"
        echo "  -n                 Executes a dry run, i.e. no changes are made to the file system with the exception of logging"
        echo "  -a ACTION          ACTION to be performed: 'backup' (Default: '${DEFAULT_ACTION}')"
        echo "  -s SEARCH_DIR      Directory to search for ${DOCKER_COMPOSE_NAME} files (Default: '${DEFAULT_SEARCH_DIR}')"
        echo "  -b BACKUP_DIR      Destination directory for backups (Default: '${DEFAULT_BACKUP_DIR}')"
        echo "  -e EXCLUDE_DIR     Directory to exclude from search (Default: '${DEFAULT_EXCLUDE_DIR}')"
        echo "  -c                 Additional docker cleanup"
        exit 0
        ;;
    d)
        log_debug "'-d' selected"
        ENABLE_DEBUG_LOGGING=true
        ;;
    n)
        log_debug "'-n' selected"
        ENABLE_DRY_RUN=true
        ;;
    a)
        log_debug "'-a' selected: '$OPTARG'"
        ACTION="${OPTARG}"
        ;;
    s)
        log_debug "'-s' selected: '$OPTARG'"
        SEARCH_DIR="${OPTARG}"
        ;;
    b)
        log_debug "'-b' selected: '$OPTARG'"
        BACKUP_DIR="${OPTARG}"
        ;;
    e)
        log_debug "'-e' selected: '$OPTARG'"
        EXCLUDE_DIR="${OPTARG}"
        ;;
    c)
        log_debug "'-c' selected"
        ENABLE_CLEANUP=true
        ;;
    \?)
        log_error "Invalid option: -$OPTARG"
        ;;
    :)
        log_error "Option -$OPTARG requires an argument!"
        ;;
    esac
done
shift $((OPTIND - 1))

# # # # # # # # # # # #|# # # # # # # # # # # #
#                  FUNCTIONS                  #
# # # # # # # # # # # #|# # # # # # # # # # # #

# Validation of the search dir and adjustments (absolute path) if necessary.
validate_search_dir() {
    if [[ "${SEARCH_DIR: -1}" != "/" ]]; then
        tmp_search_dir="${SEARCH_DIR}"
        SEARCH_DIR="${SEARCH_DIR}/"
        log_warning "SEARCH_DIR: '${tmp_search_dir}' changed to '${SEARCH_DIR}'"
    fi

    if [[ ! -d "$SEARCH_DIR" ]]; then
        log_error "The specified search directory '$SEARCH_DIR' could not be found"
    fi

    local absolute_search_dir=$(realpath "$SEARCH_DIR")

    if [[ "$SEARCH_DIR" != "$absolute_search_dir/" ]]; then
        log_warning "SEARCH_DIR: '${SEARCH_DIR}' replaced with the absolute path '${absolute_search_dir}/'"
        SEARCH_DIR="${absolute_search_dir}/"
    fi
}

# Returns the most important variables used by this script.
get_vars() {
    log_info ">>>>>>>>>>>>>>> VARIABLES >>>>>>>>>>>>>>>"
    log_info "Script name: '${SCRIPT_NAME}'"
    log_info "Log file with log dir: '${LOG_FILE_WITH_LOG_DIR}'"
    log_info "Action: '${ACTION}'"
    log_info "Search dir: '${SEARCH_DIR}'"
    log_info "Backup dir: '${BACKUP_DIR}'"
    log_info "Exclude dir: '${EXCLUDE_DIR}'"
    log_info "<<<<<<<<<<<<<<< VARIABLES <<<<<<<<<<<<<<<"
}

# Outputs information on the Docker status.
show_docker_info() {
    log_info ">>>>>>>>>>>>>>> DOCKER INFO >>>>>>>>>>>>>>>"
    log_info "docker system df..."
    log_cmd "$(docker system df)"

    log_info "docker ps..."
    log_cmd "$(docker ps)"

    log_info "docker info (formatted)..."
    log_cmd "$(docker info --format "Containers: {{.Containers}} | Running: {{.ContainersRunning}} | Paused: {{.ContainersPaused}} | Stopped: {{.ContainersStopped}} | Images: {{.Images}} | Docker Root Dir: {{.DockerRootDir}}")"

    log_info "docker images..."
    log_cmd "$(docker images)"
    log_info "<<<<<<<<<<<<<<< DOCKER INFO <<<<<<<<<<<<<<<"
}

# Searches for Docker Compose files in a specific directory and excludes a specified subdirectory.
find_docker_compose_files() {
    local docker_compose_file_names=("${DOCKER_COMPOSE_NAME}.yml" "${DOCKER_COMPOSE_NAME}.yaml")
    local docker_compose_files=""

    for name in "${docker_compose_file_names[@]}"; do
        files=$(find "$SEARCH_DIR" -path "*/${EXCLUDE_DIR}/*" -prune -o -name "$name" -print 2>/dev/null)
        if [ -n "$files" ]; then
            docker_compose_files+="$files"$'\n'
        fi
    done
    echo "$docker_compose_files"
}

# Outputs debug information for a file.
debug_file_info() {
    local func_description="$1"
    local file="$2"
    local file_dir="$3"
    local file_simple_dirname="$4"

    [[ -n "$file" ]] && log_debug "(${func_description}) file: '${file}'"
    [[ -n "$file_dir" ]] && log_debug "(${func_description}) file dir: '${file_dir}'"
    [[ -n "$file_simple_dirname" ]] && log_debug "(${func_description}) file simple dirname: '${file_simple_dirname}'"
}

# Checks whether a file has been created, if not, the script is cancelled.
check_file_creation() {
    local file=$1

    debug_file_info "Check file creation" "$file"

    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        if [[ -f "$file" ]]; then
            log_info "File created: '$file'"
        else
            log_error "File creation failed: '$file'"
        fi
    else
        log_dry_run "-f $file"
    fi
}

# Creates a backup of a Docker Compose folder by packing the files into a tar archive and then compressing them.
backup_docker_compose_folder() {
    local file=$1
    local file_dir=$(dirname "$file")
    local file_simple_dirname=$(basename "$(dirname "$file")")
    debug_file_info "Backup Docker Compose folder" "$file" "$file_dir" "$file_simple_dirname"

    local tmp_backup_dir="${BACKUP_DIR}"

    if [[ "${BACKUP_DIR: -1}" != "/" ]]; then
        BACKUP_DIR="${BACKUP_DIR}/"
        log_warning "BACKUP_DIR: '${tmp_backup_dir}' changed to '${BACKUP_DIR}'"
    fi

    BACKUP_DIR="${BACKUP_DIR}$(date +"%Y-%m-%d")/"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ "$ENABLE_DRY_RUN" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            log_info "Backup directory '$(realpath "$BACKUP_DIR")' was created"
        else
            log_dry_run "mkdir -p $BACKUP_DIR"
        fi
    fi

    local tar_file="$(date +"%Y-%m-%d_%H-%M-%S")_backup_${file_simple_dirname}.tar"
    local gz_file="${tar_file}.gz"

    local tar_file_with_backup_dir="${BACKUP_DIR}${tar_file}"
    local gz_file_with_backup_dir="${BACKUP_DIR}${gz_file}"

    log_info "TAR..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        tar -cpf "$tar_file_with_backup_dir" -C "$file_dir" . ||
            {
                log_warning "Problem while creating the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."
                rm -f "$tar_file_with_backup_dir"
                return
            }
    else
        log_dry_run "tar -cpf $tar_file_with_backup_dir -C $file_dir ."
    fi
    check_file_creation $tar_file_with_backup_dir

    log_info "GZIP..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        gzip "$tar_file_with_backup_dir" ||
            {
                log_warning "Problem while compressing the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."
                rm -f "$tar_file_with_backup_dir" "$gz_file_with_backup_dir"
                return
            }
    else
        log_dry_run "gzip $tar_file_with_backup_dir"
    fi
    check_file_creation $gz_file_with_backup_dir

    log_info "'${BACKUP_DIR}'..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$(ls -larth "${BACKUP_DIR}")"
    else
        log_dry_run "ls -larth $BACKUP_DIR"
    fi

    log_info "[-->] Backup created. You can download '${gz_file_with_backup_dir}' e.g. with FileZilla."
    log_info "[-->] To navigate to the backup folder: 'cd ${BACKUP_DIR}'"
    log_info "[-->] To move the file: '(sudo) mv ${gz_file} /my/dir/for/${DOCKER_COMPOSE_NAME}-containers/${file_simple_dirname}/'"
    log_info "[-->] To undo gzip: '(sudo) gunzip ${gz_file}'"
    log_info "[-->] To unpack the tar file: '(sudo) tar -xpf ${tar_file}'"
}

# Performs a specific action for a Docker Compose configuration file.
perform_action_for_single_docker_compose_container() {
    local file=$1
    local file_dir=$(dirname "$file")
    local file_simple_dirname=$(basename "$(dirname "$file")")
    debug_file_info "Perform action for single Docker Compose container" "$file" "$file_dir" "$file_simple_dirname"

    log_info ">>>>>>>>>> '${file}' >>>>>>>>>>"

    cd "${file_dir}"
    log_info "Changed directory to '$(pwd)'"

    log_info ">>>>> '${ACTION}' >>>>>"
    log_info "DOWN ('${file_simple_dirname}')..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$($DOCKER_COMPOSE_CMD down)"
    else
        log_dry_run "$DOCKER_COMPOSE_CMD down"
    fi

    case $ACTION in
    backup)
        backup_docker_compose_folder "$file"
        ;;
    esac

    log_info "UP ('${file_simple_dirname}')..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$($DOCKER_COMPOSE_CMD up -d)"
    else
        log_dry_run "$DOCKER_COMPOSE_CMD up -d"
    fi
    log_info "<<<<< '${ACTION}' <<<<<"
    log_info "<<<<<<<<<< '${file}' <<<<<<<<<<"
}

# Performs a specified action for all Docker Compose files in a search directory.
perform_action_for_all_docker_compose_containers() {
    log_info ">>>>>>>>>>>>>>> DOCKER COMPOSE >>>>>>>>>>>>>>>"
    case $ACTION in
    backup)
        log_debug "Action selected: '${ACTION}'"

        local docker_compose_files=$(find_docker_compose_files)

        if [ -z "$docker_compose_files" ]; then
            log_error "No ${DOCKER_COMPOSE_NAME} files found in '${SEARCH_DIR}'. Cannot perform action."
        else
            log_info "${DOCKER_COMPOSE_NAME} files: "$'\n'"${docker_compose_files}"
        fi

        while IFS= read -r file; do
            perform_action_for_single_docker_compose_container "$file"
        done <<<"$docker_compose_files"
        ;;
    *)
        log_error "Invalid action: '${ACTION}'"
        ;;
    esac
    log_info "<<<<<<<<<<<<<<< DOCKER COMPOSE <<<<<<<<<<<<<<<"
}

# Performs a cleanup of the Docker resources
cleanup() {
    log_info ">>>>>>>>>>>>>>> CLEANUP >>>>>>>>>>>>>>>"

    log_info ">>>>>>>>>> PREVIEW >>>>>>>>>>"
    log_info "Listing non-running containers..."
    log_cmd "$(docker ps -a --filter status=created --filter status=restarting --filter status=paused --filter status=exited --filter status=dead)"

    log_info "Listing unused docker images..."
    log_cmd "$(docker image ls -a --filter dangling=true)"

    log_info "Listing unused volumes..."
    log_cmd "$(docker volume ls --filter dangling=true)"
    log_info "<<<<<<<<<< PREVIEW <<<<<<<<<<"

    log_info ">>>>>>>>>> CLEAN >>>>>>>>>>"
    log_info "Removing non-running containers..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$(docker container prune -f)"
    else
        log_dry_run "docker container prune -f"
    fi

    log_info "Removing unused docker images..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$(docker image prune -f)"
    else
        log_dry_run "docker image prune -f"
    fi

    log_info "Removing unused volumes..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_cmd "$(docker volume prune -f)"
    else
        log_dry_run "docker volume prune -f"
    fi
    log_info "<<<<<<<<<< CLEAN <<<<<<<<<<"

    log_info "<<<<<<<<<<<<<<< CLEANUP <<<<<<<<<<<<<<<"
}

# # # # # # # # # # # #|# # # # # # # # # # # #
#                    LOGIC                    #
# # # # # # # # # # # #|# # # # # # # # # # # #

log_info "'$SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION' has started."

if $ENABLE_DRY_RUN; then
    log_warning "Dry run is enabled!"
fi

validate_search_dir

log_info "Current directory: '$(pwd)'"

get_vars

show_docker_info

perform_action_for_all_docker_compose_containers

if $ENABLE_CLEANUP; then
    cleanup
fi

show_docker_info

show_log_file
exit 0
