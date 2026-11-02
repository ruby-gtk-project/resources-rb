# frozen_string_literal: true

require "gtk4"

module Resources
  # Style carries the application stylesheet and installs it on a display.
  #
  # A direct port of upstream's data/resources/style.css, which upstream loads
  # from its GResource bundle in Application::setup_css. There is no bundle
  # here, so the same rules live in the string below and go onto the default
  # display through a Gtk::CssProvider.
  module Style
    CSS = <<~CSS
      progressbar.slim > trough, progressbar.slim > trough > progress {
        min-height: 4px;
      }

      .resources-columnview {
        background-color: @window_bg_color;
      }

      .bubble {
        background-color: alpha(currentColor, 0.08);
        min-width: 32px;
        min-height: 32px;
        border-radius: 50%;
      }

      .big-bubble {
        background-color: alpha(currentColor, 0.08);
        min-width: 128px;
        min-height: 128px;
        border-radius: 50%;
      }

      .small-graph {
        border-radius: 4px;
      }

      .graph {
        border-radius: 8px;
      }
    CSS

    PRIORITY_APPLICATION = 600

    def self.install(display = Gdk::Display.default)
      Gtk::StyleContext.add_provider_for_display(
        display,
        provider,
        PRIORITY_APPLICATION,
      )
    end

    def self.provider
      @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
    end
  end
end
