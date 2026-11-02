# frozen_string_literal: true

require "adwaita"

module Resources
  # ShortcutsDialog lists the keyboard shortcuts, grouped as upstream groups
  # them.
  #
  # Ported from upstream's data/resources/ui/shortcuts.ui. Each item names an
  # application action rather than a key combination, so the accelerators shown
  # are whichever ones the application has bound to that action. Upstream's
  # second section documents the Apps and Processes views' actions, and is
  # listed here once those views exist to act on.
  class ShortcutsDialog
    SECTIONS = {
      "General" => [
        ["Preferences", "app.settings"],
        ["Show Shortcuts", "app.shortcuts"],
        ["Quit", "app.quit"],
      ],
    }.freeze

    def build
      dialog.tap do |shortcuts|
        SECTIONS.each do |title, items|
          shortcuts.add(section(title, items))
        end
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      @dialog ||= Adwaita::ShortcutsDialog.new.tap do |shortcuts|
        shortcuts.title = "Keyboard Shortcuts"
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = title
          items.each { |label, action| group.add(item(label, action)) }
        end
      end

      # Positional, not keyword, arguments — the signature the bindings
      # advertise as "title: utf8, accelerator: utf8" only works positionally,
      # and the accelerator is left empty so the action name supplies it.
      def item(label, action)
        Adwaita::ShortcutsItem.new(label, "").tap do |shortcut|
          shortcut.action_name = action
        end
      end
  end
end
