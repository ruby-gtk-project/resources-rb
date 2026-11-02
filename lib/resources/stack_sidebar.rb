# frozen_string_literal: true

require "adwaita"

require_relative "settings"
require_relative "stack_sidebar_item"

module Resources
  # StackSidebar is the navigation list down the left of the window: one row
  # per page of the content stack, each row showing that page's own meter.
  #
  # Ported from upstream's data/resources/ui/widgets/stack_sidebar.ui and
  # src/ui/widgets/stack_sidebar.rs. Upstream walks the stack's pages and reads
  # each page's GObject properties; the pages here are plain objects, so the
  # sidebar is handed them directly and keeps upstream's ordering, selection
  # and last-viewed-page bookkeeping.
  class StackSidebar
    def initialize(stack, pages)
      @stack = stack
      @pages = pages
      @items = {}
    end

    attr_reader :items

    def build
      bin.tap do |sidebar|
        sidebar.child = scrolled_window

        scrolled_window.tap do |window|
          window.child = viewport

          viewport.tap do |port|
            port.child = list_box
          end
        end

        list_box.tap do |list|
          sorted_pages.each { |page| list.append(row_for(page)) }
          list.set_sort_func { |a, b| compare_rows(a, b) }
          list.signal_connect("selected-rows-changed") { |widget| on_selection_changed(widget) }
        end
      end
    end

    # Upstream re-reads every bound property on each refresh; this does the
    # same for every row at once.
    def refresh
      @items.each_value(&:update)
    end

    def select_tab_id(tab_id)
      @items.each do |row, item|
        if item.tab_id == tab_id
          list_box.select_row(row)
        end
      end
    end

    def bin = @bin ||= Adwaita::Bin.new

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.vexpand = true
      end
    end

    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :single
        list.css_classes = ["navigation-sidebar"]
      end
    end

    private

      def sorted_pages
        @pages.sort_by { |page| [page.primary_ord, page.secondary_ord] }
      end

      def row_for(page)
        StackSidebarItem.new(page).then do |item|
          Gtk::ListBoxRow.new.tap do |row|
            row.child = item.build
            row.selectable = true
            row.can_focus = true
            row.can_target = true
            row.focus_on_click = false
            @items[row] = item
          end
        end
      end

      def compare_rows(first, second)
        @items[first].then do |item|
          @items[second].then do |other|
            if item && other
              item.ord(other)
            else
              0
            end
          end
        end
      end

      # Switching rows switches the stack and records the page, as upstream's
      # connect_selected_rows_changed handler does.
      def on_selection_changed(widget)
        widget.selected_row.then do |row|
          if row
            @items[row].then do |item|
              @stack.visible_child_name = item.tab_id
              Settings.instance.last_viewed_page = item.tab_id
            end
          end
        end
      end
  end
end
