# Jumphost Tools

This repository contains shell configuration that help to access the IS
Applications jumphosts.


## Prerequisites

The tools currently work on Debian and Ubuntu WSL distributions, and require the
following packages to be installed:

- `ncat`
- `lsof`

## Configuration

Run the `setup.sh` script to install the prerequisites and copy some files into
your home directory.

If you run `./setup.sh` with no arguments, then none of your existing
configuration files will be overwritten, and you can configure your shell
manually as described below.

Alternatively, run:

```shell
$ ./setup.sh append
```

This will append the required sections to your shell configuration files.

### Manual configuration

If you have not run `./setup.sh append` then add the following to the end of
your `.bashrc` file so that the `.bashrc_jumphost` script is sourced each time
that you login:

```shell
if [ -r "${HOME}/.bashrc_jumphost" ]
then
  source $HOME/.bashrc_jumphost
fi
```

Then add the following to the end of your `.ssh/config` file so that ssh will
use the jumphost proxy for Information Services hosts:

```shell
Host gitlab.is.ed.ac.uk
  User git
  ProxyCommand none
Host *
  User isapps
  ProxyCommand ncat --proxy-type socks5 --proxy 127.0.0.1:11080 %h %p
```

Note that the entry for gitlab must remain above the wildcard entry so that git
remotes will continue to work.

## Usage

The `.bashrc_jumphost` script defines a function called `jump` that uses ssh
multiplexing to manage a background ssh connection to one of the jumphost
servers. When active, the ssh connection creates a local SOCKS5 proxy that can
be used to access our infrastructure.

Run `jump status` to show the current status of the ssh connection and the local
listening ports:

```shell
$ jump status
apps-jump-kb is connected
apps-jump-at is not connected
ssh     13486 uun    6u  IPv4  36383      0t0  TCP *:11080 (LISTEN)
ssh     13486 uun    7u  IPv6  36384      0t0  TCP *:11080 (LISTEN)
```

Run `jump start kb` or `jump start at` to connect to one of the jumphost
servers:

```shell
$ jump start kb
Enter passphrase for key '/home/uun/.ssh/jump_key':
(uun@apps-jump-kb.is.ed.ac.uk) Verification code: 5318008
```

Run `jump stop kb` or `jump stop at` to disconnect:

```shell
$ jump stop kb
Exit request sent.
```
