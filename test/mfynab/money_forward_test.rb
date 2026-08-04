# frozen_string_literal: true

require "test_helper"
require "csv"
require "mfynab/money_forward"
require "mfynab/money_forward/session"
require "support/test_loggers"
require "support/money_forward_csv"

module MFYNAB
  class MoneyForwardTest < Minitest::Test
    include TestLoggers

    def test_download_csv_downloads_csv_by_passing_a_cookie_and_converts_data_to_utf8
      session_id = "dummy_session_id"

      # Simulate a previous `mfynab login` by seeding a cookie cache file
      cookie_cache_path = File.join(Dir.mktmpdir("mfynab_test"), "cookie")
      File.write(cookie_cache_path, JSON.dump("name" => "_moneybook_session", "value" => session_id))

      session = MoneyForward::Session.new(
        logger: null_logger,
        cookie_cache_path: cookie_cache_path,
      )

      money_forward = MoneyForward.new(
        session,
        logger: null_logger,
      )

      dates = 0.upto(2).map do |i|
        first_of_the_month << i
      end
      expected_requests = dates.map do |date|
        stub_money_forward_csv_download(date: date)
          .with(headers: { cookie: "_moneybook_session=#{session_id}" })
      end

      Dir.mktmpdir do |tmpdir|
        money_forward.download_csv(
          path: tmpdir,
          months: 3,
        )
        expected_file_names = dates.map { "#{_1.strftime('%Y-%m')}.csv" }
        produced_files = Dir[File.join(tmpdir, "*.csv")]

        assert_equal expected_file_names.sort, produced_files.map { File.basename(_1) }.sort

        produced_files.each do |file|
          content = File.read(file)

          assert_equal Encoding::UTF_8, content.encoding
          assert_predicate(content, :valid_encoding?)
        end
      end

      expected_requests.each { assert_requested(_1) }
    end

    private

      def stub_money_forward_csv_download(date:, transactions: [])
        stub_request(:get, "https://moneyforward.com/cf/csv?from=#{date.strftime('%Y/%m/%d')}")
          .to_return(body: MoneyForwardCsv.new(date, transactions).to_downloaded_string)
      end

      def first_of_the_month
        today = Date.today
        today - today.day + 1
      end
  end
end
