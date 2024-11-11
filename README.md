# `domposy`: Simplify your Docker Compose management - Create backups...

<p align="center">
  <a href="./LICENSE">
    <img alt="GPL-3.0 License" src="https://img.shields.io/badge/GitHub-GPL--3.0-informational">
  </a>
</p>

<div align="center">
  <a href="https://github.com/fuchs-fabian/domposy">
    <img src="https://github-readme-stats.vercel.app/api/pin/?username=fuchs-fabian&repo=domposy&theme=holi&hide_border=true&border_radius=10" alt="Repository domposy"/>
  </a>
</div>

## Description

### What is `domposy`?

`domposy` is a Linux Bash script that helps to backup Docker Compose containers (with bind mounts).

This involves searching for the Docker Compose folder, which then also contains the `.yml` file, the bind mounts that are important for the container itself and hopefully an `.env` file.

This entire folder is then securely **tared** and then **compressed**. The backup is then located where you want it.

Timestamps are used for the backups. Help is also provided on how the backups can be reused. All important information is logged.

Finally, it is very easy to simply backup to a NAS that has been mounted with NFS or SMB, for example.

> Only Docker Compose files named `docker-compose.yml` or `docker-compose.yaml` are used for search!

Ideally, it has the following structure:

```plain
<docker-compose-project-name>/
│
├── docker-compose.yml
│
├── .env
│
└── volumes/
```

Where the files are located is almost irrelevant. Ideally, there should be a folder containing all the Docker Compose projects.

In addition, it is possible to perform a secure Docker cleanup of resources that are no longer used.

**Examples for Docker Compose files**:

<a href="https://github.com/fuchs-fabian/docker-compose-files">
  <img src="https://github-readme-stats.vercel.app/api/pin/?username=fuchs-fabian&repo=docker-compose-files&theme=holi&hide_border=true&border_radius=10" alt="Repository docker-compose-files"/>
</a>

### Who is it for?

This script is ideal for homelab enthusiasts, but also for people who work a lot with Docker Compose files.

## Getting Started

The easiest way is to download and run the [`setup.bash`](./setup.bash) script.

> If you want to install it globally, you need root rights (sudo)!\
> Otherwise, it will be only installed for the current user!

The following command will download `domposy`, make it executable, install it and then delete the `setup.bash` script:

```bash
wget -q -O setup.bash https://raw.githubusercontent.com/fuchs-fabian/domposy/refs/heads/main/setup.bash && \
chmod +x setup.bash && \
./setup.bash install && \
rm setup.bash
```

Then you can use `domposy`:

```plain
It is recommended to run the script with root rights to ensure that the backups work properly.

Usage: (sudo) domposy

  -h, --help                      Show help

  -v, --version                   Show version

  -d, --debug                     Enables debug logging

  -n, --dry-run                   Executes a dry run, i.e. no changes are made to the file system

  -a, --action    [action]        Action to be performed
                                  {backup,clean}
                                  Default: 'backup'

  --search-dir    [search dir]    Directory to search for docker-compose files
                                  Note: '-a, --action' should be used before this, otherwise it has no effect
                                  Default: '/home/'

  --exclude-dir   [exclude dir]   Directory to exclude from search
                                  Note: '-a, --action' should be used before this, otherwise it has no effect
                                  Default: 'tmp'

  --backup-dir    [backup dir]    Destination directory for backups
                                  Note: '-a, --action' should be used before this, otherwise it has no effect
                                  Default: '/tmp/domposy/backups/'

  --log-dir       [log dir]       Directory for log files
                                  Default: '/tmp/domposy/logs/'

  --notifier      [notifier]      'simbashlog' notifier (https://github.com/fuchs-fabian/simbashlog-notifiers)
                                  Important: The notifier must be correctly installed
                                  Default: none
```

### Example

```bash
domposy --action backup --search-dir /home/ --exclude-dir git --backup-dir /tmp/domposy/backups/ --log-dir /var/log/
```

### Uninstall

If you want to uninstall the script, navigate to the directory where the `setup.bash` script is located, make it executable and run it with the `uninstall` argument:

```bash
./setup.bash uninstall
```

> If the script was installed globally, you need root rights (sudo) to uninstall it!

If you can't find the `setup.bash` script anymore, you can execute the following command:

```bash
wget -q -O setup.bash https://raw.githubusercontent.com/fuchs-fabian/domposy/refs/heads/main/setup.bash && \
chmod +x setup.bash && \
./setup.bash uninstall && \
rm setup.bash
```

### Update

If you want to update the script, navigate to the directory where the `setup.bash` script is located, make it executable and run it with the `update` argument:

```bash
./setup.bash update
```

> If the script was installed globally, you need root rights (sudo) to update it!

If you can't find the `setup.bash` script anymore, you can execute the following command:

```bash
wget -q -O setup.bash https://raw.githubusercontent.com/fuchs-fabian/domposy/refs/heads/main/setup.bash && \
chmod +x setup.bash && \
./setup.bash update && \
rm setup.bash
```

#### Advanced update method

You can simply navigate to the directory in which the script is cloned, remove the execution rights and pull it. Then you can make it executable again.

## Donate with [PayPal](https://www.paypal.com/donate/?hosted_button_id=4G9X8TDNYYNKG)

If you think this tool is useful and saves you a lot of work and nerves and lets you sleep better, then a small donation would be very nice.

<a href="https://www.paypal.com/donate/?hosted_button_id=4G9X8TDNYYNKG" target="_blank">
  <!--
    https://github.com/stefan-niedermann/paypal-donate-button
  -->
  <img src="https://raw.githubusercontent.com/stefan-niedermann/paypal-donate-button/master/paypal-donate-button.png" style="height: 90px; width: 217px;" alt="Donate with PayPal"/>
</a>

---

> This repository uses [`simbashlog`](https://github.com/fuchs-fabian/simbashlog) ([LICENSE](https://github.com/fuchs-fabian/simbashlog/blob/main/LICENSE)).
>
> *Copyright (C) 2024 Fabian Fuchs*
