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

`domposy` is a Linux Bash script that helps to backup Docker Compose containers (with bind mounts). In addition, it is possible to perform a secure Docker cleanup of resources that are no longer used.

This involves searching for the Docker Compose folder, which then also contains the `.yml` file, the bind mounts that are important for the container itself and hopefully an `.env` file. 😜

This entire folder is then securely **tared** and then **compressed**. The backup is then located where you want it.

Timestamps are also used for the backups. Help is also provided on how the backups can be reused. All important information is also logged. If no container is started or a backup is created, all Docker Compose containers are automatically started afterwards.

> It may be important to adjust the directories here.

Finally, it is very easy to simply backup the whole thing to a NAS that has been mounted with NFS or SMB, for example.

> Only Docker Compose files named `docker-compose.yml` or `docker-compose.yaml` are used for search!

Ideally, it has the following structure:

```plain
<service-name>/
│
├── docker-compose.yml
│
├── .env
│
└── volumes/
```

Where the files are located is almost irrelevant. Ideally, there should be a folder containing all the services.

**Examples for Docker Compose files**:

<a href="https://github.com/fuchs-fabian/docker-compose-files">
  <img src="https://github-readme-stats.vercel.app/api/pin/?username=fuchs-fabian&repo=docker-compose-files&theme=holi&hide_border=true&border_radius=10" alt="Repository docker-compose-files"/>
</a>

### Who is it for?

This script is ideal for homelab enthusiasts, but also for people who work a lot with Docker Compose files.

> However, I do not currently recommend using it productively in a company.

### The Goal of the `domposy` Project

It is important to create backups. Unfortunately, it is not so easy for homelab enthusiasts in particular to do this easily and to run it as a cronjob. Again and again you have to write a script yourself, which is not so easy... To remedy this, there is exactly this. It is simply simple. It would be nice if Docker itself would provide such functionality in the future for exactly the kind of use case described above.

## ⚠️ **Disclaimer - Important!**

The whole thing is still at an early stage of development and can therefore lead to unexpected behaviour.

> To be used with caution.

## Getting Started

The easiest way is to download and run the setup.bash script.

<!--
TODO: Add help output
-->

### Example

<!--
TODO: Add example call
-->

## Donate with [PayPal](https://www.paypal.com/donate/?hosted_button_id=4G9X8TDNYYNKG)

If you think this tool is useful and saves you a lot of work and nerves and lets you sleep better, then a small donation would be very nice.

<a href="https://www.paypal.com/donate/?hosted_button_id=4G9X8TDNYYNKG" target="_blank">
  <!--
    https://github.com/stefan-niedermann/paypal-donate-button
  -->
  <img src="https://raw.githubusercontent.com/stefan-niedermann/paypal-donate-button/master/paypal-donate-button.png" style="height: 90px; width: 217px;" alt="Donate with PayPal"/>
</a>

## This might also interest you

[`esase`](https://github.com/fuchs-fabian/esase): Easy Setup And System Enhancement (Popup based Linux Bash script/tool)

---

> This repository uses [`simbashlog`](https://github.com/fuchs-fabian/simbashlog) ([LICENSE](https://github.com/fuchs-fabian/simbashlog/blob/main/LICENSE)).
>
> *Copyright (C) 2024 Fabian Fuchs*
