# Simple Backups

Script for taking server and workstation backups and keeping them organised


## Installation

Copy `bin/backup-server` to `/usr/local/bin` or similar, and make executable.

## Usage

Generally the tool must be run as root, because it works on files that could be owned by anyone. If your use case is simpler, it might work running as an unprivileged user.

To use the tool, set up at least one server, then run `backup-server myserver`.

Create the top-level backup folder (default /root/backup) and, within this, on folder for each server you want to back up. Name these server folders after the fully qualified hostnames of each server:

Each server folder needs a file called `files.list` listing all the patterns to be backed up

/root
    /backup
        /example1.com
            /files.list
        /example2.com
            /files.list

Example `files.list`:

```
/etc/dnsmasq.conf
/etc/host*
/var/www/**
```

The wildcard syntax is basically taken from rsync, with the added advantage that intermediate paths are automatically filled in for you to make life easier.

Make sure you have ssh (rsync) access to the server you want to back up on the root account. On first run you may be prompted to accept the servers SSH fingerprint, so make sure to run and test manually before automating your backups.

Now that you have your servers configured, you can run `backup-server example1.com` or similar to back up. Repeat as needed - the archive will be replaced by the latest backup.

Backups will be placed next to the corresponding `files.list`, like so:
/root
    /backup
        /example1.com
            /files.list
            /backup.tar
        /example2.com
            /files.list
            /backup.tar

## Options

```
backup-server
  -o OWNER        If set, the owner of the backup tar file will be changed to OWNER after creation, and the parent directory will be relative to OWNER's home folder
  -p PARENT_DIR   Set the parent directory for backup config and tar files (default: /root/backup)
  -z              If present, gzip the backup tar (filename will be backup.tar.gz)
  -s              Make an effort to save space on disk, at the cost of bandwidth and performance
  -v              If present, be noisy about what's going on
```