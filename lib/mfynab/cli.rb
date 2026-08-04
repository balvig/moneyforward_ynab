# frozen_string_literal: true

require "yaml"
require "mfynab/money_forward"
require "mfynab/money_forward/session"
require "mfynab/money_forward_data"
require "mfynab/ynab_transaction_importer"

module MFYNAB
  class CLI
    USAGE = "Usage: mfynab login | mfynab import CONFIG_FILE"

    def self.start(argv)
      new(argv).start
    end

    def initialize(argv)
      @argv = argv
    end

    def start
      case command
      when "login"
        login
      when "import"
        import
      else
        abort(USAGE)
      end
    end

    private

      attr_reader :argv

      def command
        argv[0]
      end

      # Logs in to Money Forward with credentials and saves the session
      # cookie, so that subsequent imports don't need credentials.
      def login
        MoneyForward::Session.new(
          username: ENV.fetch("MONEYFORWARD_USERNAME"),
          password: ENV.fetch("MONEYFORWARD_PASSWORD"),
          logger: logger,
        ).login

        logger.info("Session cookie saved.")
      end

      # Imports Money Forward transactions into YNAB, using a previously
      # saved session cookie. Never attempts to log in.
      def import
        logger.info("Running...")

        money_forward.update_accounts(money_forward_account_names)

        Dir.mktmpdir("mfynab") do |save_path|
          money_forward.download_csv(
            path: save_path,
            months: months_to_sync,
          )

          data = MoneyForwardData.new(logger: logger)
          data.read_all_csv(save_path)
          ynab_transaction_importer.run(data.to_h)
        end

        logger.info("Done!")
      end

      def money_forward_account_names
        @_money_forward_account_names = config["accounts"].map { _1["money_forward_name"] }
      end

      def ynab_transaction_importer
        @_ynab_transaction_importer ||= YnabTransactionImporter.new(
          config["ynab_access_token"],
          config["ynab_budget"],
          config["accounts"],
          logger: logger,
        )
      end

      def months_to_sync
        config.fetch("months_to_sync", 3)
      end

      def money_forward
        @_money_forward ||= MoneyForward.new(session, logger: logger)
      end

      def session
        @_session ||= MoneyForward::Session.new(logger: logger)
      end

      def config_file
        raise "You need to pass a config file" if argv[1].nil?

        argv[1]
      end

      def config
        @_config ||= YAML
          .load_file(config_file)
          .values
          .first
          .merge(
            "ynab_access_token" => ENV.fetch("YNAB_ACCESS_TOKEN"),
          )
      end

      def logger
        @_logger ||= Logger.new($stdout, level: logger_level)
      end

      def logger_level
        if ENV.fetch("DEBUG", nil)
          Logger::DEBUG
        else
          Logger::INFO
        end
      end
  end
end
