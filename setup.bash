#!/usr/bin/env bash

APP_NAME="domposy"
APP_BRANCH_NAME="v2"

# NOTE: The repos must contain a directory called 'src' with a bash script that has the same name as the repo and ends with '.bash'!
REPO_URLS=(
    "https://github.com/fuchs-fabian/simbashlog.git"
    "https://github.com/fuchs-fabian/${APP_NAME}.git"
)

DEPENDENCIES=(
    "git"
    "rsync"
)

OPT_DIR="/opt"

function install {
    function check_dependencies {
        for dependency in "${DEPENDENCIES[@]}"; do
            echo "Checking if '$dependency' is available..."
            command -v "$dependency" >/dev/null 2>&1 ||
                {
                    echo "'$dependency' is not available. Please install it and try again."
                    exit 1
                }
            echo "'$dependency' is available."
        done
    }

    function get_app_name_from_repo_url {
        basename "$1" .git
    }

    read -r -p "Do you want to install the $APP_NAME globally ('g') or just for the current user ('u')? (g/u): " bin_dir_choice
    if [[ "$bin_dir_choice" =~ ^[Gg]$ ]]; then
        # Symlink in /usr/bin for all users
        bin_path="/usr/bin"
    else
        # Symlink in ~/bin for the current user
        bin_path="$HOME/bin"
    fi

    for repo_url in "${REPO_URLS[@]}"; do
        app_name=$(get_app_name_from_repo_url "$repo_url")
        app_dir="$OPT_DIR/$app_name"

        if [ -d "$app_dir" ]; then
            echo "$app_name is already downloaded."
        else
            read -r -p "$app_name is not downloaded. Do you want to download it? (y/n): " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                echo "Cloning $app_name..."

                if [[ "$app_name" == "$APP_NAME" ]]; then
                    git clone --branch "$APP_BRANCH_NAME" "$repo_url" "$app_dir"
                else
                    git clone "$repo_url" "$app_dir"
                fi
            fi
        fi

        if [ -f "$app_dir/src/${app_name}.bash" ]; then
            chmod +x "$app_dir/src/${app_name}.bash"

            echo "Creating symlink for $app_name..."
            ln -sf "$app_dir/src/${app_name}.bash" "$bin_path/$app_name"
            echo "$app_name has been installed and is now executable."

            if [ -n "$(command -v "$app_name")" ]; then
                "$app_name" --version
                echo "$app_name is working."
            else
                echo "$app_name is not working."
            fi
        else
            echo "The file ${app_name}.bash was not found in the directory $app_dir/src."
        fi
    done
}

function uninstall {
    local bin_paths=(
        "/usr/bin"
        "$HOME/bin"
    )

    for repo_url in "${REPO_URLS[@]}"; do
        app_name=$(basename "$repo_url" .git)
        app_dir="$OPT_DIR/$app_name"

        for bin_path in "${bin_paths[@]}"; do
            if [ -L "$bin_path/$app_name" ]; then
                echo "Removing symlink for $app_name in $bin_path..."
                rm "$bin_path/$app_name"
            fi
        done

        if [ -d "$app_dir" ]; then
            echo "Removing directory $app_dir..."
            rm -rf "$app_dir"
        else
            echo "$app_name is not installed."
        fi
    done
}

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
