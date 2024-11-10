#!/usr/bin/env bash

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                VARIABLES                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

declare -r CONST_APP_NAME="domposy"
declare -r CONST_APP_BRANCH_NAME="v2"

declare -r CONST_LOGGER_NAME="simbashlog"
declare -r CONST_LOGGER_BRANCH_NAME="v1.1.3"

declare -r CONST_GLOBAL_DOWNLOAD_PATH="/opt"
declare -r CONST_GLOBAL_BIN_PATH="/usr/bin"

declare -r CONST_USER_DOWNLOAD_PATH="$HOME/.local/share"
declare -r CONST_USER_BIN_PATH="$HOME/.local/bin"

declare -r CONST_DEPENDENCIES=(
    "git"
    "docker"
    "tar"
    "gzip"
)

# NOTE: The repos must contain a directory called 'src' with a bash script that has the same name as the repo and ends with '.bash'!
declare -r CONST_REPO_URLS=(
    "https://github.com/fuchs-fabian/${CONST_LOGGER_NAME}.git"
    "https://github.com/fuchs-fabian/${CONST_APP_NAME}.git"
)

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  LOGIC                   ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function get_app_name_from_repo_url {
    basename "$1" .git
}

function is_root {
    [[ $(id -u) -eq 0 ]]
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                INSTALLATION                ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function install {
    local download_path=""
    local bin_path=""

    echo "Current user: '$(whoami)'"

    function check_dependencies {
        for dependency in "${CONST_DEPENDENCIES[@]}"; do
            echo "Checking if '$dependency' is available..."
            command -v "$dependency" >/dev/null 2>&1 ||
                {
                    echo "'$dependency' is not available. Please install it and try again."
                    exit 1
                }
            echo "'$dependency' is available."
        done
    }

    function create_directory {
        local directory="$1"

        if [ ! -d "$directory" ]; then
            echo "Creating directory '$directory'..."
            mkdir -p "$directory"
        fi
    }

    function set_paths {
        if is_root; then
            download_path="$CONST_GLOBAL_DOWNLOAD_PATH"
            bin_path="$CONST_GLOBAL_BIN_PATH"
        else
            echo "You are not root."
            echo "The installation will be only available for the current user."
            echo "To install it globally, please run this script as root (sudo)."

            read -r -p "Do you want to continue? [Y/n] " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                download_path="$CONST_USER_DOWNLOAD_PATH"
                bin_path="$CONST_USER_BIN_PATH"

                create_directory "$CONST_USER_DOWNLOAD_PATH"
                create_directory "$CONST_USER_BIN_PATH"
            else
                echo "Installation aborted."
                exit 1
            fi
        fi

        echo "Donwload path: '$download_path'"
        echo "Bin path: '$bin_path'"
    }

    check_dependencies
    set_paths

    for repo_url in "${CONST_REPO_URLS[@]}"; do
        local app_name
        app_name=$(get_app_name_from_repo_url "$repo_url")

        local app_path="$download_path/$app_name"

        if [ -d "$app_path" ]; then
            echo "'$app_name' is already downloaded."
        else
            echo "Downloading '$app_name'..."

            if [[ "$app_name" == "$CONST_LOGGER_NAME" ]]; then
                echo "Cloning '$CONST_LOGGER_NAME' from branch '$CONST_LOGGER_BRANCH_NAME'..."
                git clone --branch "$CONST_LOGGER_BRANCH_NAME" "$repo_url" "$app_path"

            elif [[ "$app_name" == "$CONST_APP_NAME" ]]; then
                echo "Cloning '$CONST_APP_NAME' from branch '$CONST_APP_BRANCH_NAME'..."
                git clone --branch "$CONST_APP_BRANCH_NAME" "$repo_url" "$app_path"

            else
                echo "Cloning $app_name..."
                git clone "$repo_url" "$app_path"
            fi
        fi

        local original_app_path="$app_path/src/${app_name}.bash"

        if [ -f "$original_app_path" ]; then
            echo "Making '$app_name' executable..."
            chmod +x "$original_app_path"

            echo "Creating symlink for '$app_name'..."
            ln -sf "$original_app_path" "$bin_path/$app_name"
            echo "'$app_name' has been installed and is now executable."

            if [ -n "$(command -v "$app_name")" ]; then
                "$app_name" -v
                echo "'$app_name' is working."
            else
                echo "'$app_name' is not working."
            fi
        else
            echo "The file '${app_name}.bash' was not found in '$app_path/src'."
        fi
    done
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║               UNINSTALLATION               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function uninstall {
    local download_path=""
    local bin_path=""

    function set_paths {
        if is_root; then
            download_path="$CONST_GLOBAL_DOWNLOAD_PATH"
            bin_path="$CONST_GLOBAL_BIN_PATH"
        else
            download_path="$CONST_USER_DOWNLOAD_PATH"
            bin_path="$CONST_USER_BIN_PATH"
        fi

        echo "Donwload path: '$download_path'"
        echo "Bin path: '$bin_path'"
    }

    set_paths

    for repo_url in "${CONST_REPO_URLS[@]}"; do
        app_name=$(get_app_name_from_repo_url "$repo_url")
        app_path="$download_path/$app_name"

        if [ -L "$bin_path/$app_name" ]; then
            echo "Removing symlink for '$app_name' in '$bin_path'..."
            rm "$bin_path/$app_name"
        fi

        if [ -d "$app_path" ]; then
            echo "Removing directory '$app_path'..."
            rm -rf "$app_path"
        else
            echo "'$app_name' is not installed."
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

case "$1" in
install)
    install
    ;;
uninstall)
    uninstall
    ;;
*)
    echo "Usage: $0 {install|uninstall}"
    exit 1
    ;;
esac
