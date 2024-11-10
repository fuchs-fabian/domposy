#!/usr/bin/env bash

# DESCRIPTION:
# This script simplifies your Docker Compose management.

CONST_DOMPOSY_VERSION="2.0.0"

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░              GENERAL UTILS               ░░
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

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                 LOGGING                  ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

LOGGER="simbashlog"

ORIGINAL_LOGGER_SCRIPT_PATH=$(find_bin_script "$LOGGER") ||
    {
        echo "Critical: Unable to resolve logger script '$LOGGER'. Exiting..."
        exit 1
    }

# shellcheck source=/dev/null
source "$ORIGINAL_LOGGER_SCRIPT_PATH" >/dev/null 2>&1 ||
    {
        echo "Critical: Unable to source logger script '$ORIGINAL_LOGGER_SCRIPT_PATH'. Exiting..."
        exit 1
    }

# shellcheck disable=SC2034
ENABLE_LOG_FILE=true
# shellcheck disable=SC2034
ENABLE_JSON_LOG_FILE=false
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
SHOW_CURRENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING="simple_without_file_extension"
# shellcheck disable=SC2034
ENABLE_PARENT_SCRIPT_NAME_IN_CONSOLE_OUTPUTS_FOR_LOGGING=false
# shellcheck disable=SC2034
ENABLE_SUMMARY_ON_EXIT=true

function log_debug_var {
    local scope="$1"
    log_debug "$scope -> $(print_var_with_current_value "$2")"
}

function log_dry_run {
    log_notice "Dry run is enabled. Skipping '$1'"
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
# ░░                VARIABLES                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

ENABLE_DRY_RUN=false

DOCKER_COMPOSE_NAME="docker-compose"
DOCKER_COMPOSE_CMD=""

DEFAULT_ACTION="backup"

DEFAULT_SEARCH_DIR="/home/"
DEFAULT_EXCLUDE_DIR="tmp"
DEFAULT_BACKUP_DIR="/tmp/${CONST_SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_backups/"

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

function contains_trailing_slash {
    if is_var_not_empty "$1" && [[ "${1: -1}" == "/" ]]; then
        return 0
    fi
    return 1
}

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

# Checks whether the user has root rights and if not, whether he is at least added to the 'docker' group.
function _check_permissions {
    log_notice "Current user: '$(whoami)'"
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
# ║               GET ARGUMENTS                ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

_ARG_ACTION="${DEFAULT_ACTION}"

_ARG_SEARCH_DIR="${DEFAULT_SEARCH_DIR}"
_ARG_EXCLUDE_DIR="${DEFAULT_EXCLUDE_DIR}"
_ARG_BACKUP_DIR="${DEFAULT_BACKUP_DIR}"

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
            echo "                                  Default: '${DEFAULT_ACTION}'"
            echo
            echo "  --search-dir    [search dir]    Directory to search for ${DOCKER_COMPOSE_NAME} files"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '${DEFAULT_SEARCH_DIR}'"
            echo
            echo "  --exclude-dir   [exclude dir]   Directory to exclude from search"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '${DEFAULT_EXCLUDE_DIR}'"
            echo
            echo "  --backup-dir    [backup dir]    Destination directory for backups"
            echo "                                  $note_for_valid_action_for_backup"
            echo "                                  Default: '${DEFAULT_BACKUP_DIR}'"

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

            if is_var_empty "$1"; then log_error "'$arg_which_is_processed': Value must not be empty. If you want to use the default directory do not use this option."; fi

            _ARG_SEARCH_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_SEARCH_DIR"
            ;;
        --exclude-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            _is_used_without_action_backup
            shift
            _validate_if_value_is_argument "$1"

            if is_var_empty "$1"; then log_error "'$arg_which_is_processed': Value must not be empty. If you do not want to exclude any directory do not use this option."; fi

            _ARG_EXCLUDE_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_EXCLUDE_DIR"
            ;;
        --backup-dir)
            log_debug "'$1' selected"
            arg_which_is_processed="$1"
            _is_used_without_action_backup
            shift
            _validate_if_value_is_argument "$1"

            if is_var_empty "$1"; then log_error "'$arg_which_is_processed': Value must not be empty. If you want to use the default directory do not use this option."; fi

            _ARG_BACKUP_DIR="$1"
            log_debug_var "_process_arguments" "_ARG_BACKUP_DIR"
            ;;
        *)
            log_error "Invalid argument: '$1'. $message_with_help_information"
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

function show_docker_info {
    log_delimiter_start 1 "DOCKER INFO"
    log_info "docker system df..."
    log_notice "$(docker system df)"

    log_info "docker ps..."
    log_notice "$(docker ps)"

    log_info "docker info (formatted)..."
    log_notice "$(docker info --format "Containers: {{.Containers}} | Running: {{.ContainersRunning}} | Paused: {{.ContainersPaused}} | Stopped: {{.ContainersStopped}} | Images: {{.Images}} | Docker Root Dir: {{.DockerRootDir}}")"

    log_info "docker images..."
    log_notice "$(docker images)"
    log_delimiter_end 1 "DOCKER INFO"
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

function _set_docker_compose_cmd {
    DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
    log_debug "'${DOCKER_COMPOSE_CMD}' is used"

    local version_output
    version_output=$($DOCKER_COMPOSE_CMD version 2>&1) || log_error "Failed to execute '$DOCKER_COMPOSE_CMD version'. Error: $version_output"
    log_info "$version_output"
}

function _find_docker_compose_files {
    local search_dir="$1"
    local exclude_dir="$2"

    local docker_compose_file_names=(
        "${DOCKER_COMPOSE_NAME}.yml"
        "${DOCKER_COMPOSE_NAME}.yaml"
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

    log_info "TAR..."
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

    log_info "GZIP..."
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
    log_notice ">>> To move the file: '(sudo) mv ${gz_file} /my/dir/for/${DOCKER_COMPOSE_NAME}-projects/${file_simple_dirname}/'"
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

    log_delimiter_start 2 "'${file}'"

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

    _create_backup_file_for_single_docker_compose_project "$backup_dir" "$file"

    if $is_running; then _up; else log_notice "Skip 'up' because it was not running"; fi

    log_delimiter_end 2 "'${file}'"
}

function _backup_docker_compose_projects {
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

        backup_dir="${backup_dir}$(date +"%Y-%m-%d")/"

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

    log_delimiter_start 1 "BACKUP"

    prepare_search_dir
    log_debug_var "_backup_docker_compose_projects" "search_dir"
    log_debug_var "_backup_docker_compose_projects" "exclude_dir"

    local docker_compose_files
    docker_compose_files=$(_find_docker_compose_files "$search_dir" "$exclude_dir")

    if [ -z "$docker_compose_files" ]; then
        log_error "No ${DOCKER_COMPOSE_NAME} files found in '${search_dir}'. Cannot perform backup."
    else
        log_notice "${DOCKER_COMPOSE_NAME} files: "$'\n'"${docker_compose_files}"
    fi

    prepare_backup_dir
    log_debug_var "_backup_docker_compose_projects" "backup_dir"

    while IFS= read -r file; do
        _backup_single_docker_compose_project "$backup_dir" "$file"
    done <<<"$docker_compose_files"

    log_info "'${backup_dir}'..."
    if _is_dry_run_enabled; then log_dry_run "ls -larth $backup_dir"; else log_notice "$(ls -larth "$backup_dir")"; fi

    log_delimiter_end 1 "BACKUP"
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                   CLEAN                    ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function clean_docker_environment {
    function _process_preview {
        log_delimiter_start 2 "PREVIEW"

        log_info "Listing non-running containers..."
        log_notice "$(docker ps -a --filter status=created --filter status=restarting --filter status=paused --filter status=exited --filter status=dead)"

        log_info "Listing unused docker images..."
        log_notice "$(docker image ls -a --filter dangling=true)"

        log_info "Listing unused volumes..."
        log_notice "$(docker volume ls --filter dangling=true)"

        log_delimiter_end 2 "PREVIEW"
    }

    function _process_remove {
        log_delimiter_start 2 "REMOVE"

        log_notice "Removing non-running containers..."
        if _is_dry_run_enabled; then log_dry_run "docker container prune -f"; else log_notice "$(docker container prune -f)"; fi

        log_notice "Removing unused docker images..."
        if _is_dry_run_enabled; then log_dry_run "docker image prune -f"; else log_notice "$(docker image prune -f)"; fi

        log_notice "Removing unused volumes..."
        if _is_dry_run_enabled; then log_dry_run "docker volume prune -f"; else log_notice "$(docker volume prune -f)"; fi

        log_delimiter_end 2 "REMOVE"
    }

    log_delimiter_start 1 "CLEAN"
    _process_preview
    _process_remove
    log_delimiter_end 1 "CLEAN"
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  MAIN                    ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

_process_arguments "$@"

_check_permissions

_set_docker_compose_cmd

log_notice "Current directory: '$(pwd)'"

show_docker_info

case $_ARG_ACTION in
backup)
    _backup_docker_compose_projects "$_ARG_SEARCH_DIR" "$_ARG_EXCLUDE_DIR" "$_ARG_BACKUP_DIR"
    ;;
clean)
    clean_docker_environment
    ;;
esac

show_docker_info

exit 0
