# frozen_string_literal: true

require "gtk4"

require_relative "settings"

module Resources
  # Graph draws a filled line chart of the most recent data points.
  #
  # Ported from upstream's src/ui/widgets/graph.rs. Upstream subclasses
  # GtkWidget and hands its snapshot's Cairo context to `plotters`; the Ruby
  # bindings have no plotters, so the chart is drawn directly on a
  # Gtk::DrawingArea's Cairo context — the same background tinted at a tenth of
  # the graph colour, the same area fill at four tenths, the same solid border,
  # and the same optional grid.
  class Graph
    MAX_DATA_POINTS = 600

    # Upstream fills the background with the graph colour mixed at 0.1 and the
    # area under the curve with the same colour at 0.4.
    BACKGROUND_ALPHA = 0.1
    AREA_ALPHA = 0.4
    GRID_ALPHA = 0.4

    GRID_DIVISIONS = 4

    attr_reader :color

    def initialize(height_request: 120, css_classes: ["graph"])
      @height_request = height_request
      @css_classes = css_classes
      @data_points = Array.new(MAX_DATA_POINTS, 0.0)
      @color = [0.0, 0.0, 0.0]
      @locked_max_y = 1.0
    end

    def build
      drawing_area.tap do |area|
        area.set_draw_func { |_area, context, width, height| draw(context, width, height) }
      end
    end

    def drawing_area
      @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
        area.css_classes = @css_classes
        area.height_request = @height_request
        area.overflow = :hidden
        area.hexpand = true
      end
    end

    def visible = drawing_area.visible?

    def visible=(value)
      drawing_area.visible = value
    end

    def height_request=(value)
      drawing_area.height_request = value
    end

    def css_classes=(value)
      drawing_area.css_classes = value
    end

    # Upstream takes the colour as three bytes, as its .ui files and its
    # `main_graph_color` property do.
    def set_graph_color(red, green, blue)
      @color = [red / 255.0, green / 255.0, blue / 255.0]
      drawing_area.queue_draw
    end

    # nil means "scale to the highest value in view", which is what upstream's
    # `set_locked_max_y(None)` does.
    def locked_max_y=(value)
      @locked_max_y = value
      drawing_area.queue_draw
    end

    def push_data_point(value)
      if @data_points.length >= MAX_DATA_POINTS
        @data_points.shift
      end
      @data_points.push(value)
      drawing_area.queue_draw
    end

    def push_data_points(values)
      values.each { |value| push_data_point(value) }
    end

    def clear_data_points
      @data_points = []
      drawing_area.queue_draw
    end

    def data_points = @data_points.dup

    # Upstream only considers the points actually on screen.
    def highest_value = visible_points.max.to_f

    def visible_points
      @data_points.last(Settings.instance.graph_data_points)
    end

    private

      def draw(context, width, height)
        paint_background(context, width, height)
        points = visible_points
        unless points.length < 2
          paint_chart(
            context,
            width,
            height,
            points,
          )
        end
      end

      def paint_background(context, width, height)
        context.set_source_rgba(
          @color[0],
          @color[1],
          @color[2],
          BACKGROUND_ALPHA,
        )
        context.rectangle(
          0,
          0,
          width,
          height,
        )
        context.fill
      end

      def paint_chart(context, width, height, points)
        max_y = scale(points)
        coordinates = coordinates_for(
          points,
          width,
          height,
          max_y,
        )

        if Settings.instance.show_graph_grids?
          paint_grid(context, width, height)
        end

        paint_area(context, height, coordinates)
        paint_border(context, coordinates)
      end

      # A locked maximum keeps a fraction graph pinned to 0…1; an unlocked one
      # follows the highest point in view, never dividing by zero.
      def scale(points)
        max_y = @locked_max_y
        if max_y.nil?
          max_y = points.max.to_f
        end
        if max_y.zero?
          max_y = Float::EPSILON
        end

        max_y
      end

      def coordinates_for(points, width, height, max_y)
        step = width.to_f / (points.length - 1)

        points.each_with_index.map do |value, index|
          [index * step, height - (clamp(value / max_y) * height)]
        end
      end

      def clamp(fraction)
        if fraction.finite?
          fraction.clamp(0.0, 1.0)
        else
          0.0
        end
      end

      def paint_grid(context, width, height)
        context.set_source_rgba(
          @color[0],
          @color[1],
          @color[2],
          GRID_ALPHA,
        )
        context.line_width = 1
        (1...GRID_DIVISIONS).each do |division|
          fraction = division.to_f / GRID_DIVISIONS
          context.move_to(0, height * fraction)
          context.line_to(width, height * fraction)
          context.move_to(width * fraction, 0)
          context.line_to(width * fraction, height)
        end
        context.stroke
      end

      def paint_area(context, height, coordinates)
        context.set_source_rgba(
          @color[0],
          @color[1],
          @color[2],
          AREA_ALPHA,
        )
        context.move_to(coordinates.first[0], height)
        coordinates.each { |x, y| context.line_to(x, y) }
        context.line_to(coordinates.last[0], height)
        context.close_path
        context.fill
      end

      def paint_border(context, coordinates)
        context.set_source_rgb(@color[0], @color[1], @color[2])
        context.line_width = 1
        context.move_to(coordinates.first[0], coordinates.first[1])
        coordinates.drop(1).each { |x, y| context.line_to(x, y) }
        context.stroke
      end
  end
end
