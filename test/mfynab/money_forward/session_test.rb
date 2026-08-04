# frozen_string_literal: true

require "test_helper"
require "mfynab/money_forward/session"
require "support/fake_money_forward_app"
require "support/test_loggers"

module MFYNAB
  class MoneyForward
    class SessionTest < Minitest::Test
      include TestLoggers

      def test_login_raises_if_wrong_credentials
        while_running_fake_money_forward_app do |host, port|
          session = Session.new(
            username: "david@example.com",
            password: "wrong_password",
            logger: null_logger,
            base_url: "http://#{host}:#{port}",
            cookie_cache_path: temp_cookie_cache_path,
          )

          assert_raises(RuntimeError, "Login failed") do
            session.login
          end
        end
      end

      def test_login_happy_path
        while_running_fake_money_forward_app do |host, port|
          session_cookie = Session.new(
            username: "david@example.com",
            password: "Passw0rd!",
            logger: null_logger,
            base_url: "http://#{host}:#{port}",
            cookie_cache_path: temp_cookie_cache_path,
          ).login

          assert_equal "_moneybook_session", session_cookie.name
          assert_equal "dummy_session_id", session_cookie.value
        end
      end

      private

        # Avoid clobbering the real ~/.config/mfynab/cookie when tests log in
        def temp_cookie_cache_path
          @_temp_cookie_cache_path ||= File.join(Dir.mktmpdir("mfynab_test"), "cookie")
        end

        def while_running_fake_money_forward_app
          WebMock.disable_net_connect!(allow_localhost: true)
          host = "127.0.0.1"
          port = 4567

          webapp_thread = Thread.new do
            require "rackup/handler/webrick"

            Rackup::Handler::WEBrick.run(
              FakeMoneyForwardApp,
              Host: host,
              Port: port,
              AccessLog: [],
              Logger: WEBrick::Log.new(nil, 0),
            )
          end

          Timeout.timeout(5) do
            sleep 0.1 until responsive?(webapp_thread, host, port)
          end

          yield host, port
        ensure
          webapp_thread&.terminate
          WebMock.disable_net_connect!
        end

        # Method inspired by Capybara:
        # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/server.rb#L53-L61
        def responsive?(webapp_thread, host, port)
          return false if webapp_thread&.join(0)

          res = Net::HTTP.start(host, port, max_retries: 0) do |http|
            req = Net::HTTP::Get.new("/")
            http.request(req)
          end

          res.is_a?(Net::HTTPSuccess)
        rescue SystemCallError, Net::ReadTimeout, OpenSSL::SSL::SSLError
          false
        end
    end
  end
end
