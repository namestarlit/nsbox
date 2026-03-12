# Local VM

Purpose: run a local Ubuntu VM with Vagrant and VirtualBox for repeatable script and server workflow testing.

Problem solved: quickly recreating a known local VM shape with fixed ports, memory, CPU, and a shared project directory.

Use this guide when:

- you want to run the kept scripts in a live Ubuntu environment before using them on a real host
- you want the whole repository available inside the VM for testing and iteration
- you need a disposable local box for server-style experimentation

Files in this guide:

- `Vagrantfile`: VM definition
- `install_vagrant_scp.sh`: install the `vagrant-scp` plugin
- `ssh/config`: example SSH host entry for connecting to the VM

How to run:

```bash
cd guides/local-vm
vagrant up
```

Common commands:

```bash
cd guides/local-vm
vagrant status
vagrant ssh
vagrant halt
vagrant destroy
```

Plugin helper:

```bash
bash guides/local-vm/install_vagrant_scp.sh
```

SSH config usage:

Copy or adapt `guides/local-vm/ssh/config` into your SSH config if you want a short host alias. It currently assumes:

- host IP `192.168.56.10`
- user `vagrant`
- identity file `~/.ssh/id_rsa`

VM characteristics:

- box: `ubuntu/jammy64`
- private IP: `192.168.56.10`
- forwarded ports: host `8000` -> guest `80`, host `8082` -> guest `8082`
- memory: `4096`
- cpus: `2`

Assumptions:

- Vagrant and VirtualBox are installed
- the host can use the `192.168.56.0/24` private network range
- the whole repository should be synced into the VM at `/home/vagrant/nsbox`

Risks:

- port collisions on `8000` or `8082`
- the SSH config file is only an example and may not match your local SSH key setup

Last Reviewed: 2026-03-11
