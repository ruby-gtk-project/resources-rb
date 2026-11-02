# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "main_window"
require_relative "style"

module Resources
  # Application is the entry point: it installs the stylesheet and opens the
  # main window.
  #
  # Ported from upstream's src/application.rs and src/bin/resources.rs. The
  # window actions and accelerators upstream installs here live with the window
  # that acts on them; what is left is the application object itself.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "net.nokyan.Resources"

    def initialize(options = {})
      @options = options
    end

    def build
      app.tap do
        app.signal_connect("activate") do
          Style.install
          main_window.build
          main_window.present
        end
      end
    end

    def run = app.run([])

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window's contents are Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def main_window = @main_window ||= MainWindow.new(app, @options)
  end
end
