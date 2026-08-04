#!/usr/bin/env sh

# Save environment variables to a file, so we can forward them to cron jobs
env >> /etc/environment

# Prime the cookie cache
mkdir -p ~/.config/mfynab
echo $COOKIE_CACHE_PRIME > ~/.config/mfynab/cookie

# Run cron in the foreground
cron -f
