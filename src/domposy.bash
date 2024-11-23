#!/usr/bin/env bash

# # # # # # # # # # # # # # # # # # # # # # # # #
#      _                                        #
#     | |                                       #
#   __| | ___  _ __ ___  _ __   ___  ___ _   _  #
#  / _` |/ _ \| '_ ` _ \| '_ \ / _ \/ __| | | | #
# | (_| | (_) | | | | | | |_) | (_) \__ \ |_| | #
#  \__,_|\___/|_| |_| |_| .__/ \___/|___/\__, | #
#                       | |               __/ | #
#                       |_|              |___/  #
#                                               #
# # # # # # # # # # # # # # # # # # # # # # # # #

# DISCLAIMER:
# Not POSIX conform!
#
#
# DESCRIPTION:
# This script simplifies your Docker Compose management.
#
# It is not intended to be sourced, but to be run directly.
#
# e.g.:
# ```bash
# ./domposy.bash -a backup --search-dir /data/container/ --exclude-dir git --backup-dir /mnt/backups/
# ```
#
# To summarize briefly:
# - It shows Docker information like disk usage, running containers, images etc.
# - It creates a backup of a Docker Compose project folder by packing the files into a tar archive and then compressing them.
# - It cleans the Docker environment by removing non-running containers, unused images and volumes.

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                 LICENSE                  ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

# simbashlog:
# https://github.com/fuchs-fabian/simbashlog/blob/main/LICENSE
#
# domposy:
# https://github.com/fuchs-fabian/domposy/blob/main/LICENSE

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                METADATA                  ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

declare -rx CONST_DOMPOSY_VERSION="2.1.0"
declare -rx CONST_DOMPOSY_NAME="domposy"

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                VARIABLES                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

declare -x ENABLE_DRY_RUN=false
declare -x DOCKER_COMPOSE_CMD=""

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                CONSTANTS                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

declare -rx CONST_DOCKER_COMPOSE_NAME="docker-compose"

declare -rx CONST_DEFAULT_ACTION="backup"

declare -rx CONST_DEFAULT_SEARCH_DIR="/home/"
declare -rx CONST_DEFAULT_EXCLUDE_DIR="tmp"
declare -rx CONST_DEFAULT_BACKUP_DIR="/tmp/${CONST_DOMPOSY_NAME}/backups/"
declare -rx CONST_DEFAULT_KEEP_BACKUPS="all"

declare -rx CONST_DEFAULT_LOG_DIR="/tmp/logs/"

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░              GENERAL UTILS               ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function abort {
    echo "ERROR: $1"
    echo "Aborting..."
    exit 1
}

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

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                  LOGGING                   ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

declare -rx CONST_LOGGER_NAME="simbashlog"

CONST_ORIGINAL_LOGGER_SCRIPT_PATH=$(find_bin_script "$CONST_LOGGER_NAME") ||
    abort "Unable to resolve logger script '$CONST_LOGGER_NAME'"

declare -rx CONST_ORIGINAL_LOGGER_SCRIPT_PATH

# shellcheck source=/dev/null
source "$CONST_ORIGINAL_LOGGER_SCRIPT_PATH" >/dev/null 2>&1 ||
    abort "Unable to source logger script '$CONST_ORIGINAL_LOGGER_SCRIPT_PATH'"

# shellcheck disable=SC2034
ENABLE_LOG_FILE=true
# shellcheck disable=SC2034
ENABLE_JSON_LOG_FILE=false
# shellcheck disable=SC2034
ENABLE_LOG_TO_SYSTEM=false
# shellcheck disable=SC2034
LOG_DIR="$CONST_DEFAULT_LOG_DIR"
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
SHOW_CURRENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING="simple_without_file_extension"
# shellcheck disable=SC2034
ENABLE_PARENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING=false
# shellcheck disable=SC2034
SIMBASHLOG_NOTIFIER=""
# shellcheck disable=SC2034
SIMBASHLOG_NOTIFIER_CONFIG_PATH=""
# shellcheck disable=SC2034
ENABLE_SUMMARY_ON_EXIT=true

function log_debug_var {
    local scope="$1"
    log_debug "$scope -> $(print_var_with_current_value "$2")"
}

function log_dry_run {
    log_notice "Dry run is enabled. Skipping '$1'"
}

function log_debug_delimiter {
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

    log_debug "$separator ${text} $separator"
}

function log_debug_delimiter_start {
    log_debug_delimiter "$1" "$2" ">" false
}

function log_debug_delimiter_end {
    log_debug_delimiter "$1" "$2" "<" false
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  UTILS                   ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function _is_dry_run_enabled {
    is_true "$ENABLE_DRY_RUN"
}

function _disable_notifier {
    log_debug "Notifier is disabled"
    # shellcheck disable=SC2034
    SIMBASHLOG_NOTIFIER=""
}

# Checks if a var contains a trailing slash.
function contains_trailing_slash {
    if is_var_not_empty "$1" && [[ "${1: -1}" == "/" ]]; then
        return 0
    fi
    return 1
}

# Checks if a directory exists.
function check_file_creation {
    local file=$1
    log_debug_var "check_file_creation" "file"

    if _is_dry_run_enabled; then
        log_dry_run "ls -larth $file"
    else
        if file_exists "$file"; then
            log_info "File created: '$file'"
        else
            log_error "File creation failed: '$file'"
        fi
    fi
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  LOGIC                   ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function _check_permissions {
    log_info "Current user: '$(whoami)'"
    if [[ $(id -u) -ne 0 ]]; then
        if groups "$(whoami)" | grep -q '\bdocker\b'; then
            log_warn "You do not have root rights. If you want to create backups, they may not work properly."
        else
            log_error "You need to be either a member of the 'docker' group or have root privileges to run this script."
        fi
    fi
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                 ARGUMENTS                  ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

declare -x _ARG_ACTION="${CONST_DEFAULT_ACTION}"

declare -x _ARG_SEARCH_DIR="${CONST_DEFAULT_SEARCH_DIR}"
declare -x _ARG_EXCLUDE_DIR="${CONST_DEFAULT_EXCLUDE_DIR}"
declare -x _ARG_BACKUP_DIR="${CONST_DEFAULT_BACKUP_DIR}"
declare -x _ARG_KEEP_BACKUPS="${CONST_DEFAULT_KEEP_BACKUPS}"

function _process_arguments {
    local arg_which_is_processed=""
    local message_with_help_information="Use '-h' or '--help' for more information."

    function _validate_if_value_is_short_argument {
        local value="$1"
        if [[ "$value" == "-"* && "$value" != "--"* ]]; then
            log_error "'${arg_which_is_processed}': Invalid value ('$value')! Value must not start with '-'."
        fi
    }

    function _validate_if_value_is_long_argument {
        local value="$1"
        if [[ "$value" == "--"* ]]; then
            log_error "'${arg_which_is_processed}': Invalid value ('$value')! Value must not start with '--'."
        fi
    }

    function _validate_if_value_is_argument {
        local value="$1"
        _validate_if_value_is_short_argument "$value"
        _validate_if_value_is_long_argument "$value"
    }

    function _log_error_if_value_is_empty {
        local value="$1"
        if is_var_empty "$value"; then log_error "'$arg_which_is_processed': Value must not be empty. If you want to use the default value do not use this option."; fi
    }

    local note_for_valid_action_for_backup="Note: '-a, --action' should be used before this, otherwise it has no effect"
    local is_action_backup_used=false
    function _is_used_without_action_backup {
        if is_false "$is_action_backup_used"; then
            log_warn "'$arg_which_is_processed': Should only be used if '-a, --action' is used before and set to 'backup', e.g. '... -a backup $arg_which_is_processed ...'."
        fi
    }

    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --help)
            echo "It is recommended to run the script with root rights to ensure that the backups work properly."
            echo
            echo "Usage: (sudo) $CONST_SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION"
            echo
            echo "  -h, --help                      Show help"
            echo
            echo "  -v, --version                   Show version"
            echo
            echo "  -d, --debug                     Enables debug logging"
            echo
            echo "  -n, --dry-run                   Executes a dry run, i.e. no changes are made to the file system"
            echo
            echo "  -a, --action    [action]        Action to be performed"
            echo "                                  {backup,clean}"
            echo "                                  Default: '$CONST_DEFAULT_ACTION'"
            echo
            echo "  --search-dir    [search dir]    Directory to search for $CONST_DOCKER_COMPOSE_NAME files"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '$CONST_DEFAULT_SEARCH_DIR'"
            echo
            echo "  --exclude-dir   [exclude dir]   Directory to exclude from search"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '$CONST_DEFAULT_EXCLUDE_DIR'"
            echo
            echo "  --backup-dir    [backup dir]    Destination directory for backups"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '$CONST_DEFAULT_BACKUP_DIR'"
            echo
            echo "  --keep-backups  [keep backups]  Number of backups to keep"
            echo "                                  Default: '$CONST_DEFAULT_KEEP_BACKUPS'"
            echo
            echo "  --log-dir       [log dir]       Directory for log files"
            echo "                                  Default: '$CONST_DEFAULT_LOG_DIR'"
            echo
            echo "  --enable-system-logging         Enables logging to the system"
            echo "                                  Important: Only logs warnings or more severe messages"
            echo "                                  Default: false"
            echo
            echo "  --notifier      [notifier]      '$CONST_SIMBASHLOG_NAME' notifier ($CONST_SIMBASHLOG_NOTIFIERS_GITHUB_LINK)"
            echo "                                  Important: The notifier must be correctly installed"
            echo "                                  Default: none"

            # shellcheck disable=SC2034
            ENABLE_SUMMARY_ON_EXIT=false
            exit 0
            ;;
        -v | --version)
            echo "$CONST_DOMPOSY_VERSION"

            # shellcheck disable=SC2034
            ENABLE_SUMMARY_ON_EXIT=false
            exit 0
            ;;
        -d | --debug)
            log_debug "'$1' selected"

            # shellcheck disable=SC2034
            LOG_LEVEL=7
            ;;
        -n | --dry-run)
            log_debug "'$1' selected"
            ENABLE_DRY_RUN=true

            # shellcheck disable=SC2034
            ENABLE_LOG_FILE=false
            # shellcheck disable=SC2034
            ENABLE_JSON_LOG_FILE=false
            # shellcheck disable=SC2034
            ENABLE_LOG_TO_SYSTEM=false
            # shellcheck disable=SC2034
            ENABLE_SUMMARY_ON_EXIT=false

            log_warn "Dry run is enabled!"
            ;;
        -a | --action)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            shift
            _validate_if_value_is_argument "$1"
            case $1 in
            backup)
                is_action_backup_used=true
                ;;
            clean) ;;
            *)
                log_error "Invalid action: '$1'. $message_with_help_information"
                ;;
            esac
            _ARG_ACTION="$1"
            log_debug_var "_process_arguments" "_ARG_ACTION"
            ;;
        --search-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            _is_used_without_action_backup
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            _ARG_SEARCH_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_SEARCH_DIR"
            ;;
        --exclude-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            _is_used_without_action_backup
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            _ARG_EXCLUDE_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_EXCLUDE_DIR"
            ;;
        --backup-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            _is_used_without_action_backup
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            _ARG_BACKUP_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_BACKUP_DIR"
            ;;
        --keep-backups)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            _ARG_KEEP_BACKUPS="$1"
            log_debug_var "_process_arguments" "_ARG_KEEP_BACKUPS"
            ;;
        --log-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            # shellcheck disable=SC2034
            LOG_DIR="$1"
            log_debug_var "_process_arguments" "LOG_DIR"
            ;;
        --enable-system-logging)
            log_debug "'$1' selected"
            # shellcheck disable=SC2034
            ENABLE_LOG_TO_SYSTEM=true
            ;;
        --notifier)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            shift
            _validate_if_value_is_argument "$1"
            _log_error_if_value_is_empty "$1"

            # shellcheck disable=SC2034
            SIMBASHLOG_NOTIFIER="$1"
            log_debug_var "_process_arguments" "SIMBASHLOG_NOTIFIER"
            ;;
        *)
            log_error "Invalid argument: '$1'. $message_with_help_information"

            # shellcheck disable=SC2034
            ENABLE_SUMMARY_ON_EXIT=false
            ;;
        esac
        shift
    done
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                  DOCKER                    ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

# Shows Docker information like disk usage, running containers, images etc.
function show_docker_info {
    log_debug_delimiter_start 1 "DOCKER INFO"
    log_info "docker system df..."
    log_notice "$(docker system df)"

    log_info "docker ps..."
    log_notice "$(docker ps)"

    log_info "docker info (formatted)..."
    log_notice "$(docker info --format "Containers: {{.Containers}} | Running: {{.ContainersRunning}} | Paused: {{.ContainersPaused}} | Stopped: {{.ContainersStopped}} | Images: {{.Images}} | Docker Root Dir: {{.DockerRootDir}}")"

    log_info "docker images..."
    log_notice "$(docker images)"
    log_debug_delimiter_end 1 "DOCKER INFO"
}

# Returns the Docker Compose command. So whether 'docker-compose' or 'docker compose'.
function get_docker_compose_cmd {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        log_error "Neither 'docker-compose' nor 'docker compose' command found. Is it installed?"
    fi
}

function _set_docker_compose_cmd {
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    log_debug "'${DOCKER_COMPOSE_CMD}' is used"

    local version_output
    version_output=$($DOCKER_COMPOSE_CMD version 2>&1) || log_error "Failed to execute '$DOCKER_COMPOSE_CMD version'. Error: $version_output"
    log_debug "$version_output"
}

function _find_docker_compose_files {
    local search_dir="$1"
    local exclude_dir="$2"

    local docker_compose_file_names=(
        "${CONST_DOCKER_COMPOSE_NAME}.yml"
        "${CONST_DOCKER_COMPOSE_NAME}.yaml"
    )

    local docker_compose_files=""

    for name in "${docker_compose_file_names[@]}"; do
        files=$(find "$search_dir" -path "*/${exclude_dir}/*" -prune -o -name "$name" -print 2>/dev/null)

        if is_var_not_empty "$files"; then docker_compose_files+="$files"$'\n'; fi
    done
    echo "$docker_compose_files"
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                  BACKUP                    ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

# Creates a backup of a Docker Compose project folder by packing the files into a tar archive and then compressing them.
function _create_backup_file_for_single_docker_compose_project {
    local backup_dir="$1"
    log_debug_var "_create_backup_file_for_single_docker_compose_project" "backup_dir"

    local file="$2"
    log_debug_var "_create_backup_file_for_single_docker_compose_project" "file"

    local file_dir
    file_dir=$(dirname "$file")
    log_debug_var "_create_backup_file_for_single_docker_compose_project" "file_dir"

    local file_simple_dirname
    file_simple_dirname=$(basename "$file_dir")
    log_debug_var "_create_backup_file_for_single_docker_compose_project" "file_simple_dirname"

    local tar_file
    tar_file="$(date +"%Y-%m-%d_%H-%M-%S")_backup_${file_simple_dirname}.tar"

    local gz_file="${tar_file}.gz"

    local tar_file_with_backup_dir="${backup_dir}${tar_file}"
    local gz_file_with_backup_dir="${backup_dir}${gz_file}"

    log_message_part_for_undoing_file_creations="Skipping further backup actions and undoing file creations."

    log_debug "TAR..."
    if _is_dry_run_enabled; then
        log_dry_run "tar -cpf $tar_file_with_backup_dir -C $file_dir ."
    else
        tar -cpf "$tar_file_with_backup_dir" -C "$file_dir" . ||
            {
                log_warn "Problem while creating the tar file '${tar_file_with_backup_dir}'. $log_message_part_for_undoing_file_creations"
                rm -f "$tar_file_with_backup_dir"
                return
            }
    fi
    check_file_creation "$tar_file_with_backup_dir"

    log_debug "GZIP..."
    if _is_dry_run_enabled; then
        log_dry_run "gzip $tar_file_with_backup_dir"
    else
        gzip "$tar_file_with_backup_dir" ||
            {
                log_warn "Problem while compressing the tar file '${tar_file_with_backup_dir}'. $log_message_part_for_undoing_file_creations"
                rm -f "$tar_file_with_backup_dir" "$gz_file_with_backup_dir"
                return
            }
    fi
    check_file_creation "$gz_file_with_backup_dir"

    log_notice ">>> Backup created. You can download '${gz_file_with_backup_dir}' e.g. with FileZilla."
    log_notice ">>> To navigate to the backup directory: 'cd ${backup_dir}'"
    log_notice ">>> To move the file: '(sudo) mv ${gz_file} /my/dir/for/${CONST_DOCKER_COMPOSE_NAME}-projects/${file_simple_dirname}/'"
    log_notice ">>> To undo gzip: '(sudo) gunzip ${gz_file}'"
    log_notice ">>> To unpack the tar file: '(sudo) tar -xpf ${tar_file}'"
}

function _backup_single_docker_compose_project {
    local backup_dir="$1"
    log_debug_var "_backup_single_docker_compose_project" "backup_dir"

    local file="$2"
    log_debug_var "_backup_single_docker_compose_project" "file"

    local file_dir
    file_dir=$(dirname "$file")
    log_debug_var "_backup_single_docker_compose_project" "file_dir"

    local file_simple_dirname
    file_simple_dirname=$(basename "$file_dir")
    log_debug_var "_backup_single_docker_compose_project" "file_simple_dirname"

    log_debug_delimiter_start 2 "'${file}'"

    backup_dir="${backup_dir}${file_simple_dirname}/"

    if directory_not_exists "$backup_dir"; then
        if _is_dry_run_enabled; then
            log_dry_run "mkdir -p $backup_dir"
        else
            mkdir -p "$backup_dir" || log_error "Backup directory '$backup_dir' for file '$file' could not be created"
            log_notice "Backup directory '$backup_dir' for file '$file' was created"
        fi
    fi

    cd "${file_dir}" || log_error "Failed to change directory to '${file_dir}'"
    log_notice "Changed directory to '$(pwd)'"

    function _down {
        log_info "DOWN ('${file_simple_dirname}')..."
        if _is_dry_run_enabled; then log_dry_run "$DOCKER_COMPOSE_CMD down"; else log_notice "$($DOCKER_COMPOSE_CMD down)"; fi
    }

    function _up {
        log_info "UP ('${file_simple_dirname}')..."
        if _is_dry_run_enabled; then log_dry_run "$DOCKER_COMPOSE_CMD up -d"; else log_notice "$($DOCKER_COMPOSE_CMD up -d)"; fi
    }

    local is_running=false
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        is_running=true
        log_debug "Docker-Compose project '${file}' is currently running"
    else
        log_debug "Docker-Compose project '${file}' is not running"
    fi

    if $is_running; then _down; else log_notice "Skip 'down' because it is not running"; fi

    log_info "Creating backup for '${file}'..."
    _create_backup_file_for_single_docker_compose_project "$backup_dir" "$file"

    if $is_running; then _up; else log_notice "Skip 'up' because it was not running"; fi

    log_debug_delimiter_end 2 "'${file}'"
}

function backup_docker_compose_projects {
    local search_dir="$1"
    local exclude_dir="$2"
    local backup_dir="$3"

    function prepare_search_dir {
        if ! contains_trailing_slash "$search_dir"; then search_dir="${search_dir}/"; fi

        if directory_not_exists "$search_dir"; then log_error "The specified search directory '$search_dir' could not be found"; fi

        local absolute_search_dir
        absolute_search_dir="$(realpath "$search_dir")/"

        if is_var_not_equal "$search_dir" "$absolute_search_dir"; then search_dir="$absolute_search_dir"; fi
    }

    function prepare_backup_dir {
        if ! contains_trailing_slash "$backup_dir"; then backup_dir="${backup_dir}/"; fi

        if directory_not_exists "$backup_dir"; then
            if _is_dry_run_enabled; then
                log_dry_run "mkdir -p $backup_dir"
            else
                mkdir -p "$backup_dir" || log_error "Backup directory '$backup_dir' could not be created"
                log_notice "Backup directory '$backup_dir' was created"
            fi
        fi

        local absolute_backup_dir
        absolute_backup_dir="$(realpath "$backup_dir")/"

        if is_var_not_equal "$backup_dir" "$absolute_backup_dir"; then backup_dir="$absolute_backup_dir"; fi
    }

    log_debug_delimiter_start 1 "BACKUP"

    prepare_search_dir
    log_debug_var "backup_docker_compose_projects" "search_dir"
    log_debug_var "backup_docker_compose_projects" "exclude_dir"

    local docker_compose_files
    docker_compose_files=$(_find_docker_compose_files "$search_dir" "$exclude_dir")

    if [ -z "$docker_compose_files" ]; then
        log_error "No ${CONST_DOCKER_COMPOSE_NAME} files found in '${search_dir}'. Cannot perform backup."
    else
        log_notice "${CONST_DOCKER_COMPOSE_NAME} files: "$'\n'"${docker_compose_files}"
    fi

    prepare_backup_dir
    log_debug_var "backup_docker_compose_projects" "backup_dir"

    while IFS= read -r file; do
        _backup_single_docker_compose_project "$backup_dir" "$file"
    done <<<"$docker_compose_files"

    log_info "Backup directory content ('${backup_dir}'):"
    if _is_dry_run_enabled; then log_dry_run "ls -larth $backup_dir"; else log_notice "$(ls -larth "$backup_dir")"; fi

    log_debug_delimiter_end 1 "BACKUP"
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                   CLEAN                    ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

# Cleans the Docker environment by removing non-running containers, unused images and volumes.
function clean_docker_environment {
    function _process_preview {
        log_debug_delimiter_start 2 "PREVIEW"

        log_info "Listing non-running containers..."
        log_notice "$(docker ps -a --filter status=created --filter status=restarting --filter status=paused --filter status=exited --filter status=dead)"

        log_info "Listing unused docker images..."
        log_notice "$(docker image ls -a --filter dangling=true)"

        log_info "Listing unused volumes..."
        log_notice "$(docker volume ls --filter dangling=true)"

        log_debug_delimiter_end 2 "PREVIEW"
    }

    function _process_remove {
        log_debug_delimiter_start 2 "REMOVE"

        log_info "Removing non-running containers..."
        if _is_dry_run_enabled; then log_dry_run "docker container prune -f"; else log_notice "$(docker container prune -f)"; fi

        log_info "Removing unused docker images..."
        if _is_dry_run_enabled; then log_dry_run "docker image prune -f"; else log_notice "$(docker image prune -f)"; fi

        log_info "Removing unused volumes..."
        if _is_dry_run_enabled; then log_dry_run "docker volume prune -f"; else log_notice "$(docker volume prune -f)"; fi

        log_debug_delimiter_end 2 "REMOVE"
    }

    log_debug_delimiter_start 1 "CLEAN"
    _process_preview
    _process_remove
    log_debug_delimiter_end 1 "CLEAN"
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             DELETE OLD BACKUPS             ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function _delete_old_files {
    local dir="$1"
    local keep_files="$2"

    log_debug_var "_delete_old_files" "dir"
    log_debug_var "_delete_old_files" "keep_files"

    if ! contains_trailing_slash "$dir"; then dir="${dir}/"; fi

    log_info "Processing directory '$dir' for deletion of old files (keep: $keep_files)..."

    # Get all files sorted by date
    mapfile -t files < <(ls -dt "$dir"*)

    if is_var_empty "${files[*]}"; then
        log_warn "No files found in '$dir'. Skipping deletion of old files."
        return 1
    fi

    local number_of_files="${#files[@]}"

    log_debug "Files in '$dir' (number: $number_of_files):"
    for file in "${files[@]}"; do
        log_debug "'$file'"
    done

    if ((${#files[@]} > keep_files)); then
        local files_to_delete=("${files[@]:keep_files}")
        local number_of_files_to_delete="${#files_to_delete[@]}"

        log_info "Old files to delete ($number_of_files_to_delete/$number_of_files):"
        for file_to_delete in "${files_to_delete[@]}"; do
            log_info "'$file_to_delete'"
        done

        for file_to_delete in "${files_to_delete[@]}"; do
            log_info "Deleting old file '$file_to_delete'..."

            if _is_dry_run_enabled; then
                log_dry_run "rm -rf $file_to_delete"
            else
                rm -rf "$file_to_delete" || log_error "Failed to delete file: '$file_to_delete'"
            fi

            log_notice "Old file deleted: '$file_to_delete'"
        done
    else
        log_notice "No files to delete. All files are kept. (number of files: $number_of_files | keep: $keep_files)"
    fi
}

function delete_old_backups {
    local backup_dir="$1"
    local keep_backups="$2"

    log_debug_var "delete_old_backups" "backup_dir"
    log_debug_var "delete_old_backups" "keep_backups"

    if ! contains_trailing_slash "$backup_dir"; then backup_dir="${backup_dir}/"; fi

    if directory_not_exists "$backup_dir"; then
        log_warn "Backup directory '$backup_dir' does not exist. Skipping deletion of old backups."
        return 1
    fi

    if is_var_equal "$keep_backups" "all"; then
        log_notice "All backups are kept. No backups will be deleted."
        return 0
    fi

    if is_not_numeric "$keep_backups"; then
        log_warn "Keep backups is not a number. Skipping deletion of old backups."
        return 1
    fi

    if is_less "$keep_backups" 1; then
        log_warn "It is not possible to keep less than 1 backup. You have to delete the backups manually."
        return 1
    fi

    for sub_dir in "$backup_dir"*/; do
        if directory_exists "$sub_dir"; then
            _delete_old_files "$sub_dir" "$keep_backups" ||
                log_warn "Deletion of old backups in '$sub_dir' failed"
        else
            log_warn "No subdirectories found in '$backup_dir'."
            return 1
        fi
    done
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  MAIN                    ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

_process_arguments "$@"

if _is_dry_run_enabled; then _disable_notifier; fi

_check_permissions
_set_docker_compose_cmd

log_info "Current directory: '$(pwd)'"

show_docker_info

case $_ARG_ACTION in
backup)
    backup_docker_compose_projects "$_ARG_SEARCH_DIR" "$_ARG_EXCLUDE_DIR" "$_ARG_BACKUP_DIR"
    ;;
clean)
    clean_docker_environment
    ;;
esac

log_debug_delimiter_start 1 "DELETE OLD BACKUPS"
delete_old_backups "$_ARG_BACKUP_DIR" "$_ARG_KEEP_BACKUPS" ||
    log_warn "Deletion of old backups could not be completed"
log_debug_delimiter_end 1 "DELETE OLD BACKUPS"

show_docker_info

exit 0
