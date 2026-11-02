# frozen_string_literal: true

require "adwaita"

require_relative "rb/version"

module Resources
  # AboutDialog credits upstream's authors and links to its issue tracker.
  #
  # Ported from upstream's Application::show_about_dialog in src/application.rs.
  # The credits name upstream's developer and artist; the version is this
  # port's own, since that is the code the dialog is reporting on.
  class AboutDialog
    APPLICATION_NAME = "Resources"
    APPLICATION_ICON = "net.nokyan.Resources"
    DEVELOPER_NAME = "nokyan"
    DEVELOPERS = ["nokyan <hello@nokyan.net>"].freeze
    ARTISTS = ["Avhiren"].freeze
    ISSUE_URL = "https://github.com/nokyan/resources/issues"
    WEBSITE = "https://apps.gnome.org/app/net.nokyan.Resources/"

    def build
      dialog
    end

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |about|
        about.application_name = APPLICATION_NAME
        about.application_icon = APPLICATION_ICON
        about.developer_name = DEVELOPER_NAME
        about.developers = DEVELOPERS
        about.artists = ARTISTS
        about.issue_url = ISSUE_URL
        about.website = WEBSITE
        about.license_type = Gtk::License::GPL_3_0
        about.version = Resources::Rb::VERSION
      end
    end
  end
end
