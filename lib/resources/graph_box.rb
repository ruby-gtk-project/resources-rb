# frozen_string_literal: true

require "adwaita"

require_relative "graph"
require_relative "units"

module Resources
  # GraphBox is a preferences row holding one graph, a title and a line of
  # usage detail, and the arithmetic that turns a raw reading into both.
  #
  # Ported from upstream's data/resources/ui/widgets/graph_box.ui and
  # src/ui/widgets/graph_box.rs. The `add_*_point` methods keep upstream's
  # division of labour: a reading with a known maximum is shown as a clamped
  # fraction with "used / total · percentage", and one without is shown
  # unclamped with "value · Highest: value".
  class GraphBox
    NOT_AVAILABLE = "N/A"

    def initialize
      @graph = Graph.new
    end

    attr_reader :graph

    def build
      row.tap do |preferences_row|
        preferences_row.child = box

        box.tap do |outer|
          outer.append(graph.build)
          outer.append(label_box)

          label_box.tap do |labels|
            labels.append(title_label)
            labels.append(info_label)
          end
        end
      end
    end

    def set_title_label(text)
      title_label.label = text
    end

    def set_subtitle(text)
      info_label.label = text
    end

    def set_tooltip(text)
      info_label.tooltip_text = text
    end

    # Upstream's add_fraction_point: a reading that is already a 0…1 fraction.
    def add_fraction_point(fraction)
      if fraction.nil?
        unavailable
      else
        Units.convert_fraction(fraction, true).tap do |subtitle|
          graph.visible = true
          set_subtitle(subtitle)
          graph.push_data_point(fraction)
          graph.locked_max_y = 1.0
        end
      end
    end

    # Upstream's add_storage_point.
    def add_storage_point(used_bytes, total_bytes)
      add_maybe_clamped_point(used_bytes&.to_f, total_bytes&.to_f) do |bytes|
        Units.convert_storage(bytes, false)
      end
    end

    # Upstream's add_temperature_point.
    def add_temperature_point(temperature)
      add_unclamped_point(temperature) { |celsius| Units.convert_temperature(celsius) }
    end

    # Upstream's add_power_point.
    def add_power_point(power_usage, max_power)
      add_maybe_clamped_point(power_usage, max_power) { |watts| Units.convert_power(watts) }
    end

    # Upstream's add_speed_point.
    def add_speed_point(bytes_per_second)
      add_unclamped_point(bytes_per_second) { |speed| Units.convert_speed(speed, false) }
    end

    # Upstream's add_speed_point_network, which honours the bits-per-second
    # setting.
    def add_speed_point_network(bytes_per_second)
      add_unclamped_point(bytes_per_second) { |speed| Units.convert_speed(speed, true) }
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
      @box ||= Gtk::Box.new(:vertical, 12).tap do |outer|
        outer.margin_start = 12
        outer.margin_end = 12
        outer.margin_top = 6
        outer.margin_bottom = 6
        outer.hexpand = true
      end
    end

    def label_box
      @label_box ||= Gtk::Box.new(:vertical, 4).tap do |labels|
        labels.hexpand = true
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.css_classes = ["subtitle"]
        label.hexpand = true
        label.halign = :start
        label.ellipsize = :middle
      end
    end

    def info_label
      @info_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.selectable = true
        label.ellipsize = :middle
      end
    end

    private

      def add_maybe_clamped_point(value, max_value, &stringify)
        if value && max_value
          clamped_subtitle(value, max_value, &stringify)
        elsif value
          add_unclamped_point(value, &stringify)
        else
          graph.visible = false
          unavailable
        end
      end

      def clamped_subtitle(value, max_value, &stringify)
        fraction = finite_or_zero(value / max_value)
        percentage = Units.convert_fraction(fraction, true)
        subtitle = "#{stringify.call(value)} / #{stringify.call(max_value)} · #{percentage}"

        graph.visible = true
        set_subtitle(subtitle)
        graph.push_data_point(fraction)
        graph.locked_max_y = 1.0

        subtitle
      end

      def add_unclamped_point(value, &stringify)
        graph.visible = !value.nil?
        if value.nil?
          unavailable
        else
          unclamped_subtitle(value, &stringify)
        end
      end

      def unclamped_subtitle(value, &stringify)
        stringify.call(value).tap do |value_string|
          highest = stringify.call(graph.highest_value)

          set_subtitle("#{value_string} · Highest: #{highest}")
          graph.push_data_point(value)
          graph.locked_max_y = nil
        end
      end

      def unavailable
        set_subtitle(NOT_AVAILABLE)

        NOT_AVAILABLE
      end

      def finite_or_zero(value)
        if value.finite?
          value
        else
          0.0
        end
      end
  end
end
