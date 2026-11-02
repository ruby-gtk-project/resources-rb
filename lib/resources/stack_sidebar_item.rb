# frozen_string_literal: true

require "adwaita"

require_relative "graph"
require_relative "settings"

module Resources
  # StackSidebarItem is one row of the sidebar: icon, name, optional device
  # description, optional usage detail, and a meter that is either a progress
  # bar or a small graph.
  #
  # Ported from upstream's data/resources/ui/widgets/stack_sidebar_item.ui and
  # src/ui/widgets/stack_sidebar_item.rs. Upstream exposes name, detail,
  # subtitle, icon and usage as GObject properties so the page can bind to
  # them; here the page is a plain object, so `update` pulls the same five
  # values off it whenever the sidebar refreshes.
  class StackSidebarItem
    GRAPH_HEIGHT = 64

    attr_reader :tab_id, :primary_ord, :secondary_ord

    def initialize(page)
      @page = page
      @tab_id = page.tab_id
      @primary_ord = page.primary_ord
      @secondary_ord = page.secondary_ord
      @graph = Graph.new(height_request: GRAPH_HEIGHT, css_classes: ["small-graph"])
    end

    attr_reader :graph

    def build
      bin.tap do |item|
        item.child = box

        box.tap do |outer|
          outer.append(heading_box)
          outer.append(detail_label)
          outer.append(usage_label)
          outer.append(progress_bar)
          outer.append(graph.build)

          heading_box.tap do |heading|
            heading.append(image)
            heading.append(label)
          end
        end

        apply_colour
        apply_settings
        update
      end
    end

    # Upstream binds each label to the page's property; the equivalent here is
    # re-reading them on every refresh.
    def update
      label.label = @page.tab_name
      image.gicon = Gio::ThemedIcon.new(@page.icon_name)
      usage_label.label = @page.tab_usage_string
      detail_label.label = @page.tab_detail_string
      apply_detail_visibility
      if @page.uses_progress_bar
        push_usage(@page.usage)
      end
    end

    # Upstream's set_usage: the progress bar is scaled against the highest
    # value the graph has seen, never below 1.0.
    def push_usage(usage)
      highest = [graph.highest_value, 1.0].max
      progress_bar.fraction = (usage / highest).clamp(0.0, 1.0)
      graph.push_data_point(usage)
    end

    # Upstream's ord(): primary order first, secondary as the tie-break.
    def ord(other)
      [primary_ord, secondary_ord] <=> [other.primary_ord, other.secondary_ord]
    end

    def bin
      @bin ||= Adwaita::Bin.new.tap do |item|
        item.css_classes = ["sidebar-item"]
        item.margin_top = 12
        item.margin_bottom = 12
        item.margin_start = 8
        item.margin_end = 8
      end
    end

    def box = @box ||= Gtk::Box.new(:vertical, 4)
    def heading_box = @heading_box ||= Gtk::Box.new(:horizontal, 12)

    def image
      @image ||= Gtk::Image.new.tap do |icon|
        icon.pixel_size = 16
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |text|
        text.xalign = 0
        text.hexpand = true
        text.ellipsize = :end
      end
    end

    def detail_label
      @detail_label ||= Gtk::Label.new.tap do |text|
        text.xalign = 0
        text.hexpand = true
        text.ellipsize = :end
        text.css_classes = ["caption"]
      end
    end

    def usage_label
      @usage_label ||= Gtk::Label.new.tap do |text|
        text.xalign = 0
        text.hexpand = true
        text.ellipsize = :end
        text.css_classes = ["subtitle"]
      end
    end

    def progress_bar
      @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
        bar.css_classes = ["slim"]
      end
    end

    private

      def apply_colour
        @page.main_graph_color.then do |colour|
          graph.set_graph_color(colour[0], colour[1], colour[2])
        end
        graph.locked_max_y = locked_max_y
      end

      def locked_max_y
        if @page.graph_locked_max_y
          1.0
        end
      end

      # A page without a meter shows neither; a page with one follows the
      # sidebar-meter-type setting, as upstream's connect_sidebar_meter_type
      # handler does.
      def apply_settings
        usage_label.visible = Settings.instance.sidebar_details?
        Settings.instance.on_change("sidebar-details") do |visible|
          usage_label.visible = visible
        end

        Settings.instance.on_change("sidebar-description") do
          apply_detail_visibility
        end

        apply_meter
      end

      def apply_meter
        if @page.uses_progress_bar
          apply_meter_type
          Settings.instance.on_change("sidebar-meter-type") { apply_meter_type }
        else
          progress_bar.visible = false
          graph.visible = false
        end
      end

      def apply_meter_type
        progress_bar.visible = Settings.instance.sidebar_progress_bars?
        graph.visible = Settings.instance.sidebar_graphs?
      end

      # Upstream disables the description regardless of the setting when the
      # page does not provide one.
      def apply_detail_visibility
        detail_label.visible = Settings.instance.sidebar_description? &&
          !@page.tab_detail_string.to_s.empty?
      end
  end
end
