# CHANGELOG.md

## (unreleased)

- Split the CLI into two commands: `mfynab login` logs in to Money Forward
  and saves the session cookie, `mfynab import` imports transactions into
  YNAB using the saved cookie (and never logs in).
- Read secrets from environment variables (`MONEYFORWARD_USERNAME`,
  `MONEYFORWARD_PASSWORD`, `YNAB_ACCESS_TOKEN`) instead of the
  configuration file.
- Log in with a visible browser, leaving time to complete Money Forward's
  additional email authentication when it is requested.
- Refresh accounts on Money Forward before syncing transactions to YNAB.
- (Fix) Handle scenario where multiple YNAB accounts may match the partial
  string passed in the config file.
- Increase memo and payee max lengths, following changes in YNAB's API.

## 0.1.4 (2024-08-25)

- Fix `months_to_sync` configuration key not being used
- Log how many transactions were actually imported vs duplicates
