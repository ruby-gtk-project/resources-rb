# frozen_string_literal: true

require "adwaita"

require_relative "graph"

module Resources
  # DoubleGraphBox is a preferences row holding two graphs side by side, each
  # with its own title and detail line — read and write, or receive and send.
  #
  # Ported from upstream's data/resources/ui/widgets/double_graph_box.ui and
  # src/ui/widgets/double_graph_box.rs.
  class DoubleGraphBox
    def initialize
      @start_graph = Graph.new
      @end_graph = Graph.new
    end

    attr_reader :start_graph, :end_graph

    def build
      row.tap do |preferences_row|
        preferences_row.child = box

        box.tap do |outer|
          outer.append(start_box)
          outer.append(end_box)

          start_box.tap do |side|
            side.append(start_graph.build)
            side.append(start_label_box)

            start_label_box.tap do |labels|
              labels.append(start_title_label)
              labels.append(start_info_label)
            end
          end

          end_box.tap do |side|
            side.append(end_graph.build)
            side.append(end_label_box)

            end_label_box.tap do |labels|
              labels.append(end_title_label)
              labels.append(end_info_label)
            end
          end
        end
      end
    end

    def set_graphs_visible(visible)
      start_graph.visible = visible
      end_graph.visible = visible
    end

    def set_start_title_label(text)
      start_title_label.label = text
    end

    def set_start_subtitle(text)
      start_info_label.label = text
    end

    def set_start_tooltip(text)
      start_info_label.tooltip_text = text
    end

    def set_end_title_label(text)
      end_title_label.label = text
    end

    def set_end_subtitle(text)
      end_info_label.label = text
    end

    def set_end_tooltip(text)
      end_info_label.tooltip_text = text
    end

    def row
      @row ||= Adwaita::PreferencesRow.new.tap do |preferences_row|
        preferences_row.hexpand = true
        preferences_row.overflow = :hidden
        preferences_row.activatable = false
        preferences_row.width_request = 160
      end
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 12).tap do |outer|
        outer.margin_start = 12
        outer.margin_end = 12
        outer.margin_top = 12
        outer.margin_bottom = 6
        outer.hexpand = true
      end
    end

    def start_box = @start_box ||= side_box
    def end_box = @end_box ||= side_box
    def start_label_box = @start_label_box ||= label_box
    def end_label_box = @end_label_box ||= label_box
    def start_title_label = @start_title_label ||= title_label
    def end_title_label = @end_title_label ||= title_label
    def start_info_label = @start_info_label ||= info_label
    def end_info_label = @end_info_label ||= info_label

    private

      def side_box
        Gtk::Box.new(:vertical, 12).tap do |side|
          side.hexpand = true
        end
      end

      def label_box
        Gtk::Box.new(:vertical, 4).tap do |labels|
          labels.hexpand = true
        end
      end

      def title_label
        Gtk::Label.new.tap do |label|
          label.css_classes = ["subtitle"]
          label.hexpand = true
          label.halign = :start
          label.ellipsize = :middle
        end
      end

      def info_label
        Gtk::Label.new.tap do |label|
          label.hexpand = true
          label.halign = :start
          label.selectable = true
          label.ellipsize = :middle
        end
      end
  end
end
