# frozen_string_literal: true

require "adwaita"

require_relative "process"

module Resources
  # ProcessActionDialog is the confirmation dialog the Processes and
  # Applications pages both open before ending, halting or killing one or
  # more processes. Continuing a stopped process skips the dialog entirely,
  # on both pages, since there is nothing destructive to confirm.
  #
  # Ported from the identical `get_action_name`/`get_action_warning`/
  # `get_action_description` helpers and `connect_response` wiring that
  # appear twice in upstream, once each in src/ui/pages/processes/mod.rs and
  # src/ui/pages/applications/mod.rs.
  class ProcessActionDialog
    CANCEL = "no"
    CONFIRM = "yes"

    ACTION_NAMES = {
      Process::Action::TERM => "End %s?",
      Process::Action::STOP => "Halt %s?",
      Process::Action::KILL => "Kill %s?",
      Process::Action::CONT => "Continue %s?",
    }.freeze

    # Upstream's ni18n_f picks between a singular and a plural literal by
    # count; CONT's singular literal really is "Kill process?" in upstream,
    # not "Continue process?", which this keeps faithfully.
    ACTION_NAMES_SINGULAR = {
      Process::Action::TERM => "End process?",
      Process::Action::STOP => "Halt process?",
      Process::Action::KILL => "Kill process?",
      Process::Action::CONT => "Kill process?",
    }.freeze

    ACTION_NAMES_MULTIPLE = {
      Process::Action::TERM => "End %d processes?",
      Process::Action::STOP => "Halt %d processes?",
      Process::Action::KILL => "Kill %d processes?",
      Process::Action::CONT => "Kill %d processes?",
    }.freeze

    ACTION_WARNINGS = {
      Process::Action::TERM => "Unsaved work might be lost.",
      Process::Action::STOP => "Halting a process can come with serious risks such as " \
        "losing data and security implications. Use with caution.",
      Process::Action::KILL => "Killing a process can come with serious risks such as " \
        "losing data and security implications. Use with caution.",
      Process::Action::CONT => "",
    }.freeze

    ACTION_DESCRIPTIONS = {
      Process::Action::TERM => "End Process",
      Process::Action::STOP => "Halt Process",
      Process::Action::KILL => "Kill Process",
      Process::Action::CONT => "Continue Process",
    }.freeze

    class << self
      # Upstream's get_action_name: the single-subject heading, naming either
      # the one process or the one app the row represents.
      def action_name(action, name)
        format(ACTION_NAMES.fetch(action), name)
      end

      # Upstream's get_action_name_multiple, used only on the Processes page,
      # where several selected rows can be acted on at once.
      def action_name_multiple(action, count)
        if count == 1
          ACTION_NAMES_SINGULAR.fetch(action)
        else
          format(ACTION_NAMES_MULTIPLE.fetch(action), count)
        end
      end

      def action_warning(action) = ACTION_WARNINGS.fetch(action)
      def action_description(action) = ACTION_DESCRIPTIONS.fetch(action)
    end

    # `heading` and `warning` are the already-formatted strings (built with
    # the class methods above); `on_confirm` is called with no arguments when
    # the destructive response is chosen, and never when the dialog is
    # cancelled or dismissed.
    def initialize(heading:, warning:, action:, on_confirm:)
      @heading = heading
      @warning = warning
      @action = action
      @on_confirm = on_confirm
    end

    def present(parent)
      dialog.choose(parent, nil) do |_source, result|
        if dialog.choose_finish(result) == CONFIRM
          @on_confirm.call
        end
      end
    end

    private

      def dialog
        @dialog ||= Adwaita::AlertDialog.new(@heading, @warning).tap do |alert|
          alert.add_response(CONFIRM, self.class.action_description(@action))
          alert.set_response_appearance(CONFIRM, :destructive)
          alert.add_response(CANCEL, "Cancel")
          alert.default_response = CANCEL
          alert.close_response = CANCEL
        end
      end
  end
end
