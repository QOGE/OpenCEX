# Host recovery helpers

For a **new** install, start with [`POST-INSTALL.md`](POST-INSTALL.md) (before `opencex.sh` and again after the wizard).

See `DEPLOYMENT.md` for live image pins, git remotes, and overlay paths on the development box. Do not rerun `opencex.sh` on a host that already has a database.

`opencex-backup.sh` is installed on the exchange box as `/usr/local/sbin/opencex-backup.sh` and run from `/etc/cron.d/opencex-backup` (03:15 UTC).

`opencex-health.sh` is `/usr/local/sbin/opencex-health.sh` (mode 700) and run from `/etc/cron.d/opencex-health` every 5 minutes. It checks Redis, Postgres, QOGE RPC TCP, QOGE cursor stall (gap > 50 with an unchanged cursor), and the public ticker. Status is `/var/lib/opencex/health.status`. Docker healthchecks on gunicorn, `opencex-qoge`, Redis, Postgres, and frontend are in the live compose file; they do not detect a stalled QOGE cursor.

Dumps and config copies land in `/root/opencex-backups/` (directory mode 700, files mode 600). Keeper/wizard material stays in `/root/opencex-custody/` and is not rotated by this script.

Restore into a **throwaway** Postgres container. Do not restore over the live `postgresql` volume.
