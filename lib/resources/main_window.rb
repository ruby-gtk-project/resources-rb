# frozen_string_literal: true

require "adwaita"

require_relative "about_dialog"
require_relative "battery"
require_relative "battery_page"
require_relative "cpu"
require_relative "cpu_page"
require_relative "memory"
require_relative "memory_page"
require_relative "settings"
require_relative "settings_dialog"
require_relative "shortcuts_dialog"
require_relative "stack_sidebar"

module Resources
  # MainWindow is the whole window: a collapsible sidebar listing the pages, a
  # stack holding them, and the refresh loop that feeds them.
  #
  # Ported from upstream's data/resources/ui/window.ui and src/ui/window.rs,
  # including the primary menu the header bar's button opens. Upstream's
  # template subclasses AdwApplicationWindow, which the Ruby bindings cannot
  # instantiate; a Gtk::ApplicationWindow holding an Adwaita::BreakpointBin
  # takes its place, which is what carries the same max-width breakpoint.
  class MainWindow
    WIDTH_REQUEST = 360
    HEIGHT_REQUEST = 240

    BREAKPOINT_CONDITION = "max-width: 780sp"

    # Every refresh speed upstream offers is a whole multiple of this, so one
    # timeout at this interval can serve all of them.
    TICK_INTERVAL = 250

    # Upstream's primary_menu, in window.ui.
    PRIMARY_MENU = [
      ["Preferences", "app.settings"],
      ["Keyboard Shortcuts", "app.shortcuts"],
      ["About Resources", "app.about"],
    ].freeze

    # Upstream's accelerators, from Application::setup_accels.
    ACCELERATORS = {
      "app.quit"     => ["<Control>q", "<Control>w"],
      "app.settings" => ["<Control>comma"],
    }.freeze

    def initialize(app, options = {})
      @app = app
      @options = options
      @first_refresh = true
    end

    def build
      window.tap do |win|
        win.child = breakpoint_bin

        breakpoint_bin.tap do |bin|
          bin.child = content_box
          bin.add_breakpoint(breakpoint)

          content_box.tap do |column|
            column.append(split_view)

            split_view.tap do |view|
              view.sidebar = sidebar_toolbar
              view.content = content_stack

              sidebar_toolbar.tap do |toolbar|
                toolbar.add_top_bar(sidebar_header)
                toolbar.content = sidebar.build

                sidebar_header.pack_end(menu_button)
              end

              pages.each { |page| content_stack.add_named(page_toolbar(page), page.tab_id) }
            end
          end
        end

        win.signal_connect("close-request") { on_close_request }

        install_actions
        Settings.instance.apply_to(win)
        start_refresh_loop
      end
    end

    def present
      window.present
    end

    def window
      @window ||= Gtk::ApplicationWindow.new(@app).tap do |win|
        win.title = "Resources"
        win.width_request = WIDTH_REQUEST
        win.height_request = HEIGHT_REQUEST
      end
    end

    def breakpoint_bin
      @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap do |bin|
        bin.width_request = WIDTH_REQUEST
        bin.height_request = HEIGHT_REQUEST
      end
    end

    # Below the breakpoint the sidebar becomes an overlay rather than a pane,
    # as upstream's AdwBreakpoint setter does.
    def breakpoint
      @breakpoint ||= Adwaita::Breakpoint
        .new(Adwaita::BreakpointCondition.parse(BREAKPOINT_CONDITION))
        .tap do |point|
          point.add_setter(split_view, "collapsed", true)
        end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def split_view = @split_view ||= Adwaita::OverlaySplitView.new

    def sidebar_toolbar
      @sidebar_toolbar ||= Adwaita::ToolbarView.new.tap do |toolbar|
        toolbar.css_classes = ["undershoot-top"]
      end
    end

    def sidebar_header = @sidebar_header ||= Adwaita::HeaderBar.new

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Open menu"
        button.menu_model = primary_menu
      end
    end

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        PRIMARY_MENU.each { |label, action| menu.append(label, action) }
      end
    end

    def content_stack
      @content_stack ||= Gtk::Stack.new.tap do |stack|
        stack.vexpand = true
        stack.vhomogeneous = false
      end
    end

    def sidebar = @sidebar ||= StackSidebar.new(content_stack, pages)

    # Upstream's pages are added by the window template and then removed when
    # the matching --disable-… flag is given; here the flag keeps the page out
    # of the list in the first place.
    def pages
      @pages ||= [cpu_page, memory_page, *battery_pages].compact
    end

    def cpu_page
      unless defined?(@cpu_page)
        @cpu_page = nil
        unless @options[:disable_cpu_monitoring]
          @cpu_page = CpuPage.new(cpu_info)
        end
      end

      @cpu_page
    end

    def memory_page
      unless defined?(@memory_page)
        @memory_page = nil
        unless @options[:disable_memory_monitoring]
          @memory_page = MemoryPage.new
        end
      end

      @memory_page
    end

    def battery_pages
      @battery_pages ||= if @options[:disable_battery_monitoring]
        []
      else
        Battery.sysfs_paths.each_with_index.map { |path, index| BatteryPage.new(path, index) }
      end
    end

    def cpu_info = @cpu_info ||= Cpu.info

    def about_dialog = @about_dialog ||= AboutDialog.new
    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new
    def settings_dialog = @settings_dialog ||= SettingsDialog.new

    private

      # Each page sits in its own toolbar view with a flat header bar, a title
      # and the sidebar toggle, exactly as upstream's add_page builds it.
      def page_toolbar(page)
        Adwaita::ToolbarView.new.tap do |toolbar|
          toolbar.add_top_bar(page_header(page))
          toolbar.content = page.build
        end
      end

      def page_header(page)
        Adwaita::HeaderBar.new.tap do |header|
          header.css_classes = ["flat"]
          header.title_widget = page_title(page)
          header.pack_start(sidebar_toggle)
        end
      end

      # The Processor page titles itself with the processor's model name and
      # keeps "Processor" as its subtitle, as upstream's setup_widgets does.
      def page_title(page)
        Adwaita::WindowTitle.new(page_heading(page), page_subheading(page))
      end

      def page_heading(page)
        page.tab_detail_string.to_s.empty?.then do |blank|
          if blank
            page.tab_name
          else
            page.tab_detail_string
          end
        end
      end

      def page_subheading(page)
        page.tab_detail_string.to_s.empty?.then do |blank|
          if blank
            ""
          else
            page.tab_name
          end
        end
      end

      def sidebar_toggle
        Gtk::ToggleButton.new.tap do |button|
          button.icon_name = "sidebar-show-symbolic"
          button.tooltip_text = "Toggle sidebar"
          split_view.bind_property(
            "collapsed",
            button,
            "visible",
            :sync_create,
          )
          split_view.bind_property(
            "show-sidebar",
            button,
            "active",
            [:sync_create, :bidirectional],
          )
        end
      end

      def install_actions
        actions.each do |name, callback|
          Gio::SimpleAction.new(name, nil).tap do |action|
            action.signal_connect("activate") { callback.call }
            @app.add_action(action)
          end
        end

        ACCELERATORS.each do |action, accelerators|
          @app.set_accels_for_action(action, accelerators)
        end
      end

      def actions
        {
          "quit"      => -> { quit },
          "settings"  => -> { settings_dialog.build.present(window) },
          "shortcuts" => -> { shortcuts_dialog.build.present(window) },
          "about"     => -> { about_dialog.build.present(window) },
        }
      end

      # Upstream drives the refresh from an async loop that re-reads its delay
      # each time round, so a change to the refresh speed takes effect at once.
      # One repeating timeout counting ticks does the same without replacing
      # the timeout source every period.
      def start_refresh_loop
        @elapsed = 0
        GLib::Timeout.add(TICK_INTERVAL) do
          @elapsed += TICK_INTERVAL
          if @elapsed >= interval_in_milliseconds
            @elapsed = 0
            refresh
          end
          true
        end
      end

      def interval_in_milliseconds
        (Settings.instance.ui_refresh_interval * 1000).round
      end

      def refresh
        refresh_cpu
        refresh_memory
        refresh_batteries
        sidebar.refresh
        open_last_viewed_page
      end

      def refresh_cpu
        cpu_page&.refresh_page(Cpu.data(cpu_info.logical_cpus || 0))
      end

      def refresh_batteries
        battery_pages.each { |page| page.refresh_page(Battery.data_for(page.sysfs_path)) }
      end

      def refresh_memory
        memory_page.then do |page|
          Memory.data.then do |data|
            if page && data
              page.refresh_page(data)
            end
          end
        end
      end

      # Upstream opens the page the last session ended on, or the one named by
      # --open-tab-id, once the first refresh has filled the sidebar.
      def open_last_viewed_page
        if @first_refresh
          @first_refresh = false
          wanted = @options[:open_tab_id] || Settings.instance.last_viewed_page
          if pages.any? { |page| page.tab_id == wanted }
            content_stack.visible_child_name = wanted
            sidebar.select_tab_id(wanted)
          end
        end
      end

      # Closing the window first so the close handler saves the geometry, then
      # quitting, is the order upstream's quit action uses.
      def quit
        window.close
        @app.quit
      end

      def on_close_request
        Settings.instance.remember(window)

        false
      end
  end
end
