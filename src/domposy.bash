#!/usr/bin/env bash

# DESCRIPTION:
# This script simplifies your Docker Compose management.

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░             SOURCING HELPER              ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function find_bin_script {
    local script_name="$1"
    local bin_paths=(
        "/bin"
        "/usr/bin"
        "/usr/local/bin"
        "$HOME/bin"
    )

    for bin_path in "${bin_paths[@]}"; do
        local path="$bin_path/$script_name"

        if [ -L "$path" ]; then
            local original_path
            original_path=$(readlink -f "$path")

            if [ -f "$original_path" ]; then
                echo "$original_path"
                return 0
            fi
        elif [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    echo "Error: '$script_name' not found in the specified bin paths (${bin_paths[*]// /, })." >&2
    return 1
}

function source_bin_script {
    local script_name="$1"
    local script_path

    script_path=$(find_bin_script "$script_name") || return 1

    # shellcheck source=/dev/null
    source "$script_path" ||
        {
            echo "Error: Unable to source script '$script_path'"
            return 1
        }
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░             LOGGING HELPER               ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

LOGGER="simbashlog"

source_bin_script "$LOGGER" ||
    {
        echo "Critical: Unable resolve logger script '$LOGGER'. Exiting..."
        exit 1
    }

# shellcheck disable=SC2034
ENABLE_LOG_FILE=true
# shellcheck disable=SC2034
ENABLE_LOG_TO_SYSTEM=false
# shellcheck disable=SC2034
LOG_DIR="/tmp/simbashlogs/"
# shellcheck disable=SC2034
ENABLE_SIMPLE_LOG_DIR_STRUCTURE=true
# shellcheck disable=SC2034
ENABLE_COMBINED_LOG_FILES=false
# shellcheck disable=SC2034
LOG_LEVEL=6
# shellcheck disable=SC2034
LOG_LEVEL_FOR_SYSTEM_LOGGING=4
# shellcheck disable=SC2034
FACILITY_NAME_FOR_SYSTEM_LOGGING="user"
# shellcheck disable=SC2034
ENABLE_EXITING_SCRIPT_IF_AT_LEAST_ERROR_IS_LOGGED=true
# shellcheck disable=SC2034
ENABLE_DATE_IN_CONSOLE_OUTPUTS_FOR_LOGGING=true
# shellcheck disable=SC2034
SHOW_CURRENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING="path"
# shellcheck disable=SC2034
ENABLE_PARENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING=false
# shellcheck disable=SC2034
ENABLE_SUMMARY_ON_EXIT=true

function log_dry_run {
    log_info "Dry run is enabled. Skipping '$1'"
}

function log_delimiter {
    local level="$1"
    local text="$2"
    local char="$3"
    local use_uppercase="$4"
    local number
    local separator=""

    case $level in
    1) number=15 ;;
    2) number=10 ;;
    3) number=5 ;;
    *) number=3 ;;
    esac

    for ((i = 0; i < number; i++)); do
        separator+="$char"
    done

    if is_true "$use_uppercase"; then
        text=$(to_uppercase "$text")
    fi

    log_info "$separator ${text} $separator"
}

function log_delimiter_start {
    log_delimiter "$1" "$2" ">" false
}

function log_delimiter_end {
    log_delimiter "$1" "$2" "<" false
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░              PREPARATIONS                ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

# Checks whether the user has root rights and if not, whether he is at least added to the 'docker' group.
function check_permissions {
    log_notice "Current user: '$(whoami)'"
    if [[ $(id -u) -ne 0 ]]; then
        if groups "$(whoami)" | grep -q '\bdocker\b'; then
            log_warn "You do not have root rights. If you want to create backups, they may not work properly."
        else
            log_error "You need to be either a member of the 'docker' group or have root privileges to run this script."
        fi
    fi
}

# Returns the Docker Compose command. So whether 'docker-compose' or 'docker compose'.
function get_docker_compose_command {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        log_error "Neither 'docker-compose' nor 'docker compose' command found. Is it installed?"
    fi
}

# Validates whether the docker compose command can also be executed by determining the version.
function validate_docker_compose_command {
    local version_output
    version_output=$($DOCKER_COMPOSE_CMD version 2>&1) || log_error "Failed to execute '$DOCKER_COMPOSE_CMD version'. Error: $version_output"
    log_info "$version_output"
}

check_permissions

DOCKER_COMPOSE_NAME="docker-compose" # Name for Docker Compose files and path components

DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
log_debug "'${DOCKER_COMPOSE_CMD}' is used"
validate_docker_compose_command

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                ARGUMENTS                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

DEFAULT_ACTION="backup"
DEFAULT_SEARCH_DIR="/home/"
DEFAULT_BACKUP_DIR="/tmp/${CONST_SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_backups/"
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
        echo "Usage: (sudo) $CONST_SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION [-h] [-d] [-n] [-a ACTION] [-s SEARCH_DIR] [-b BACKUP_DIR] [-e EXCLUDE_DIR] [-c]"
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
        # shellcheck disable=SC2034
        LOG_LEVEL=7
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

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                FUNCTIONS                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

# Validation of the search dir and adjustments (absolute path) if necessary.
function validate_search_dir {
    if [[ "${SEARCH_DIR: -1}" != "/" ]]; then
        tmp_search_dir="${SEARCH_DIR}"
        SEARCH_DIR="${SEARCH_DIR}/"
        log_warn "SEARCH_DIR: '${tmp_search_dir}' changed to '${SEARCH_DIR}'"
    fi

    if [[ ! -d "$SEARCH_DIR" ]]; then
        log_error "The specified search directory '$SEARCH_DIR' could not be found"
    fi

    local absolute_search_dir
    absolute_search_dir=$(realpath "$SEARCH_DIR")

    if [[ "$SEARCH_DIR" != "$absolute_search_dir/" ]]; then
        log_warn "SEARCH_DIR: '${SEARCH_DIR}' replaced with the absolute path '${absolute_search_dir}/'"
        SEARCH_DIR="${absolute_search_dir}/"
    fi
}

# Returns the most important variables used by this script.
function get_vars {
    log_delimiter_start 1 "VARIABLES"
    log_notice "Action: '${ACTION}'"
    log_notice "Search dir: '${SEARCH_DIR}'"
    log_notice "Backup dir: '${BACKUP_DIR}'"
    log_notice "Exclude dir: '${EXCLUDE_DIR}'"
    log_delimiter_end 1 "VARIABLES"
}

# Outputs information on the Docker status.
function show_docker_info {
    log_delimiter_start 1 "DOCKER INFO"
    log_notice "docker system df..."
    log_info "$(docker system df)"

    log_notice "docker ps..."
    log_info "$(docker ps)"

    log_notice "docker info (formatted)..."
    log_info "$(docker info --format "Containers: {{.Containers}} | Running: {{.ContainersRunning}} | Paused: {{.ContainersPaused}} | Stopped: {{.ContainersStopped}} | Images: {{.Images}} | Docker Root Dir: {{.DockerRootDir}}")"

    log_notice "docker images..."
    log_info "$(docker images)"
    log_delimiter_end 1 "DOCKER INFO"
}

# Searches for Docker Compose files in a specific directory and excludes a specified subdirectory.
function find_docker_compose_files {
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
function debug_file_info {
    local func_description="$1"
    local file="$2"
    local file_dir="$3"
    local file_simple_dirname="$4"

    [[ -n "$file" ]] && log_debug "(${func_description}) file: '${file}'"
    [[ -n "$file_dir" ]] && log_debug "(${func_description}) file dir: '${file_dir}'"
    [[ -n "$file_simple_dirname" ]] && log_debug "(${func_description}) file simple dirname: '${file_simple_dirname}'"
}

# Checks whether a file has been created, if not, the script is cancelled.
function check_file_creation {
    local file=$1

    debug_file_info "Check file creation" "$file"

    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        if [[ -f "$file" ]]; then
            log_notice "File created: '$file'"
        else
            log_error "File creation failed: '$file'"
        fi
    else
        log_dry_run "-f $file"
    fi
}

# Creates a backup of a Docker Compose folder by packing the files into a tar archive and then compressing them.
function backup_docker_compose_folder {
    local file=$1

    local file_dir
    file_dir=$(dirname "$file")

    local file_simple_dirname
    file_simple_dirname=$(basename "$(dirname "$file")")

    debug_file_info "Backup Docker Compose folder" "$file" "$file_dir" "$file_simple_dirname"

    local tmp_backup_dir="${BACKUP_DIR}"

    if [[ "${BACKUP_DIR: -1}" != "/" ]]; then
        BACKUP_DIR="${BACKUP_DIR}/"
        log_warn "BACKUP_DIR: '${tmp_backup_dir}' changed to '${BACKUP_DIR}'"
    fi

    BACKUP_DIR="${BACKUP_DIR}$(date +"%Y-%m-%d")/"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ "$ENABLE_DRY_RUN" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            log_notice "Backup directory '$(realpath "$BACKUP_DIR")' was created"
        else
            log_dry_run "mkdir -p $BACKUP_DIR"
        fi
    fi

    local tar_file
    tar_file="$(date +"%Y-%m-%d_%H-%M-%S")_backup_${file_simple_dirname}.tar"

    local gz_file="${tar_file}.gz"

    local tar_file_with_backup_dir="${BACKUP_DIR}${tar_file}"
    local gz_file_with_backup_dir="${BACKUP_DIR}${gz_file}"

    log_notice "TAR..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        tar -cpf "$tar_file_with_backup_dir" -C "$file_dir" . ||
            {
                log_warn "Problem while creating the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."
                rm -f "$tar_file_with_backup_dir"
                return
            }
    else
        log_dry_run "tar -cpf $tar_file_with_backup_dir -C $file_dir ."
    fi
    check_file_creation "$tar_file_with_backup_dir"

    log_notice "GZIP..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        gzip "$tar_file_with_backup_dir" ||
            {
                log_warn "Problem while compressing the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."
                rm -f "$tar_file_with_backup_dir" "$gz_file_with_backup_dir"
                return
            }
    else
        log_dry_run "gzip $tar_file_with_backup_dir"
    fi
    check_file_creation "$gz_file_with_backup_dir"

    log_notice "'${BACKUP_DIR}'..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$(ls -larth "${BACKUP_DIR}")"
    else
        log_dry_run "ls -larth $BACKUP_DIR"
    fi

    log_notice "[-->] Backup created. You can download '${gz_file_with_backup_dir}' e.g. with FileZilla."
    log_notice "[-->] To navigate to the backup folder: 'cd ${BACKUP_DIR}'"
    log_notice "[-->] To move the file: '(sudo) mv ${gz_file} /my/dir/for/${DOCKER_COMPOSE_NAME}-containers/${file_simple_dirname}/'"
    log_notice "[-->] To undo gzip: '(sudo) gunzip ${gz_file}'"
    log_notice "[-->] To unpack the tar file: '(sudo) tar -xpf ${tar_file}'"
}

# Performs a specific action for a Docker Compose configuration file.
function perform_action_for_single_docker_compose_container {
    local file=$1

    local file_dir
    file_dir=$(dirname "$file")

    local file_simple_dirname
    file_simple_dirname=$(basename "$(dirname "$file")")

    debug_file_info "Perform action for single Docker Compose container" "$file" "$file_dir" "$file_simple_dirname"

    log_delimiter_start 2 "'${file}'"

    cd "${file_dir}" || log_error "Failed to change directory to '${file_dir}'"

    log_notice "Changed directory to '$(pwd)'"

    log_delimiter_start 3 "'${ACTION}'"

    log_notice "DOWN ('${file_simple_dirname}')..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$($DOCKER_COMPOSE_CMD down)"
    else
        log_dry_run "$DOCKER_COMPOSE_CMD down"
    fi

    case $ACTION in
    backup)
        backup_docker_compose_folder "$file"
        ;;
    esac

    log_notice "UP ('${file_simple_dirname}')..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$($DOCKER_COMPOSE_CMD up -d)"
    else
        log_dry_run "$DOCKER_COMPOSE_CMD up -d"
    fi

    log_delimiter_end 3 "'${ACTION}'"
    log_delimiter_end 2 "'${file}'"
}

# Performs a specified action for all Docker Compose files in a search directory.
function perform_action_for_all_docker_compose_containers {
    log_delimiter_start 1 "DOCKER COMPOSE"
    case $ACTION in
    backup)
        log_debug "Action selected: '${ACTION}'"

        local docker_compose_files
        docker_compose_files=$(find_docker_compose_files)

        if [ -z "$docker_compose_files" ]; then
            log_error "No ${DOCKER_COMPOSE_NAME} files found in '${SEARCH_DIR}'. Cannot perform action."
        else
            log_notice "${DOCKER_COMPOSE_NAME} files: "$'\n'"${docker_compose_files}"
        fi

        while IFS= read -r file; do
            perform_action_for_single_docker_compose_container "$file"
        done <<<"$docker_compose_files"
        ;;
    *)
        log_error "Invalid action: '${ACTION}'"
        ;;
    esac
    log_delimiter_end 1 "DOCKER COMPOSE"
}

# Performs a cleanup of the Docker resources
function cleanup {
    log_delimiter_start 1 "CLEANUP"

    log_delimiter_start 2 "PREVIEW"
    log_notice "Listing non-running containers..."
    log_info "$(docker ps -a --filter status=created --filter status=restarting --filter status=paused --filter status=exited --filter status=dead)"

    log_notice "Listing unused docker images..."
    log_info "$(docker image ls -a --filter dangling=true)"

    log_notice "Listing unused volumes..."
    log_info "$(docker volume ls --filter dangling=true)"
    log_delimiter_end 2 "PREVIEW"

    log_delimiter_start 2 "CLEAN"
    log_notice "Removing non-running containers..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$(docker container prune -f)"
    else
        log_dry_run "docker container prune -f"
    fi

    log_notice "Removing unused docker images..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$(docker image prune -f)"
    else
        log_dry_run "docker image prune -f"
    fi

    log_notice "Removing unused volumes..."
    if [[ "$ENABLE_DRY_RUN" == false ]]; then
        log_info "$(docker volume prune -f)"
    else
        log_dry_run "docker volume prune -f"
    fi
    log_delimiter_end 2 "CLEAN"

    log_delimiter_end 1 "CLEANUP"
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  MAIN                    ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

log_notice "'$CONST_SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION' has started."

if $ENABLE_DRY_RUN; then
    log_warn "Dry run is enabled!"
fi

validate_search_dir

log_notice "Current directory: '$(pwd)'"

get_vars

show_docker_info

perform_action_for_all_docker_compose_containers

if $ENABLE_CLEANUP; then
    cleanup
fi

show_docker_info

exit 0
