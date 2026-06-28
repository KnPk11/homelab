#!/bin/sh
password=$(tr -d '\n' < /run/secrets/password_standard)

# Only create user, don't define any shares (-s is skipped)
exec samba.sh -u "K;$password"