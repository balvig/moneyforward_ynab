# MoneyForward to YNAB migrator

This Ruby script downloads transaction history from Money Forward then uploads
it to YNAB.

## Principle

- Use [Ferrum](https://github.com/rubycdp/ferrum) to browse to the Money Forward
  website, log in and save a session cookie.
- Craft HTTP requests to Money Forward including the session cookie above to
  retrieve transactions in CSV files.
- Parse the CSV files and convert the data to a format that works with YNAB.
- Use [YNAB API Ruby library](https://github.com/ynab/ynab-sdk-ruby) to post
  transactions to your YNAB budget.
- Budget and account mappings are set in a configuration file (see `config/example.yml`).

## Setup

You'll need Ruby 3.3.0 or above.

```sh
# Install gem
gem install mfynab

# Start a config YAML file
wget https://raw.githubusercontent.com/davidstosik/moneyforward_ynab/main/config/example.yml -O mfynab-david.yml
```

The script currently looks for credentials in environment variables:

- `MONEYFORWARD_USERNAME`
- `MONEYFORWARD_PASSWORD`
- `YNAB_ACCESS_TOKEN`

You can for example use [dotenv](https://github.com/bkeepers/dotenv)
to store your secrets in a `.env` file:

```
MONEYFORWARD_USERNAME=david@example.com
MONEYFORWARD_PASSWORD=Passw0rd!
YNAB_ACCESS_TOKEN=abunchofcharacters
```

<a name="one-password-cli"></a>

Alternatively, you can also use something like [1Password's CLI](https://developer.1password.com/docs/cli/)
to avoid storing clear secrets:

```
MONEYFORWARD_USERNAME=op://Private/Moneyforward/username
MONEYFORWARD_PASSWORD=op://Private/Moneyforward/password
YNAB_ACCESS_TOKEN=op://Private/YNAB/secrets/API token
```

## Running

Running MFYNAB is a two-step process:

1. `mfynab login` logs in to Money Forward using `MONEYFORWARD_USERNAME` and
   `MONEYFORWARD_PASSWORD`, then saves the session cookie to
   `~/.config/mfynab/cookie`. The login happens in a visible browser window,
   giving you time to complete Money Forward's additional email
   authentication if it is requested. This only needs to happen once:
   Money Forward expires sessions after 30 days without use, so as long as
   imports run regularly, the cookie stays valid.
2. `mfynab import CONFIG_FILE` downloads transactions from Money Forward
   using the saved session cookie (it never logs in), and imports them into
   YNAB using `YNAB_ACCESS_TOKEN`.

Using `dotenv`, that'll look like this:

```sh
dotenv mfynab login
dotenv mfynab import mfynab-david.yml
```

Using 1Password's CLI, that would look like this:

```sh
op run --env-file=.env -- mfynab login
op run --env-file=.env -- mfynab import mfynab-david.yml
```

## Development

After checking out the repo, run `bundle install` to install dependencies.
Then, run `bin/rake test` to run the tests.

## Deploying with Kamal

The `deploy/` directory contains a [Kamal](https://kamal-deploy.org/) project
that runs `mfynab import` on a schedule (see `deploy/config/crontab`) inside a
Docker container on a remote server.

How it works:

- The Docker image installs mfynab from a GitHub branch (see `deploy/Gemfile`)
  and runs cron in the foreground.
- Secrets are fetched from 1Password at deploy time (see `deploy/.kamal/secrets`).
- The server never logs in to Money Forward: the local session cookie saved by
  `mfynab login` is passed to the container as the `COOKIE_CACHE_PRIME`
  environment variable and written to the container's cookie cache on boot
  (see `deploy/entrypoint.sh`). This avoids Money Forward's additional email
  authentication, which a headless server cannot complete.

To deploy:

```sh
mfynab login               # unless you already have a valid session cookie
cd deploy
bundle install
bundle exec kamal setup    # first deploy; use `kamal deploy` afterwards
```

To trigger a sync manually, or follow the logs:

```sh
bundle exec kamal app exec --reuse "bundle exec mfynab import config/mfynab.yml"
bundle exec kamal app logs -f
```

If the session cookie ever expires, run `mfynab login` locally again, then
`bundle exec kamal deploy` to push the new cookie to the server.

## Roadmap

- Save the session cookie again after every request. Money Forward refreshes
  the `_moneybook_session` cookie's expiry date on each request, so re-saving
  it would keep the session alive indefinitely.
- Use Thor to manage the CLI. (And/or TTY?)
- Implement `Transaction` model to extract some logic from existing classes.
- Handle the Amazon account differently (use account name as payee instead of content?)
- Generate new configuration file with the command line.
- Make reusable fixtures instead of setting up every test
- Why does it show a higher number in imported, than importing?
- Passing logger everywhere feels weird.
- One might want to run a single Docker instance for multiple users, but the current setup does not allow that easily. We'll want to bring the secret environment variables into the config file, making it possible to assign them to a given "user", and name them accordingly.
