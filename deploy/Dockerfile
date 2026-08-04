FROM ruby:3.4

# Install cron and chromium
RUN apt-get update && apt-get install -y cron chromium

WORKDIR /app

# Copy Gemfile first and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application (this two-step process helps with layer caching)
COPY . .

# Add cron job
RUN crontab /app/config/crontab

# Add a health check to ensure the cron process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD pgrep cron

# Run the entrypoint script by default
CMD [ "/app/entrypoint.sh" ]
