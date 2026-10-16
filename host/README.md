# Host recovery helpers

`opencex-backup.sh` is installed on the exchange box as `/usr/local/sbin/opencex-backup.sh` and run from `/etc/cron.d/opencex-backup` (03:15 UTC).

Dumps and config copies land in `/root/opencex-backups/` (directory mode 700, files mode 600). Keeper/wizard material stays in `/root/opencex-custody/` and is not rotated by this script.

Restore into a **throwaway** Postgres container. Do not restore over the live `postgresql` volume.
