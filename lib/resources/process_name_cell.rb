# frozen_string_literal: true

require "adwaita"

module Resources
  # ProcessNameCell is the two-part cell (an icon beside an elided name) that
  # the Processes page's name column uses for every row.
  #
  # Ported from upstream's data/resources/ui/widgets/process_name_cell.ui and
  # src/ui/pages/processes/process_name_cell.rs. Upstream is a GObject
  # subclass with `name`/`tooltip`/`icon`/`symbolic` properties bound from a
  # `Gtk::SignalListItemFactory`; this is a plain widget wrapper with the same
  # four setters, which a factory's `setup`/`bind` callbacks call directly
  # instead of going through GObject property bindings.
  class ProcessNameCell
    GENERIC_ICON = "generic-process"

    def initialize
      @icon = Gio::ThemedIcon.new(GENERIC_ICON)
      @symbolic = false
    end

    def build
      box.tap do |cell|
        cell.append(image)
        cell.append(inscription)
      end
    end

    attr_reader :icon, :symbolic

    def name = inscription.text.to_s

    def name=(value)
      inscription.text = value
    end

    def tooltip = inscription.tooltip_text.to_s

    def tooltip=(value)
      inscription.tooltip_text = value
    end

    # Upstream only re-sets the image when the icon actually changed, since
    # `set_from_gicon` is comparatively expensive; this skips the same way.
    def icon=(value)
      unless value == @icon
        image.gicon = value
        @icon = value
      end
    end

    def symbolic=(value)
      @symbolic = value
      image.css_classes = value ? [] : ["lowres-icon"]
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 12)
    end

    def image
      @image ||= Gtk::Image.new.tap do |icon_image|
        icon_image.pixel_size = 16
        icon_image.css_classes = ["lowres-icon"]
      end
    end

    def inscription
      @inscription ||= Gtk::Inscription.new.tap do |label|
        label.xalign = 0
        label.yalign = 0.5
        label.hexpand = true
        label.vexpand = true
        label.valign = :center
        label.text_overflow = :ellipsize_end
        label.min_chars = 12
      end
    end
  end
end
