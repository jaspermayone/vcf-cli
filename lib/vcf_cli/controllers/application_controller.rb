# frozen_string_literal: true

module VcfCli
  module Controllers
    class ApplicationController
      attr_reader :contact_book, :screen, :input, :list_view, :detail_view, :status_bar
      attr_accessor :mode, :filter, :running

      def initialize(contact_book)
        @contact_book = contact_book
        @screen = Services::ScreenManager.new
        @input = Services::InputHandler.new
        @mode = :normal  # :normal, :search, :edit, :confirm_delete, :confirm_quit, :duplicates
        @filter = ""
        @running = true
        @pending_action = nil
        @duplicates_view = nil

        setup_views
      end

      def run
        screen.setup
        render

        while running
          handle_input
          status_bar.clear_expired_message
        end
      ensure
        screen.teardown
      end

      private

      def setup_views
        screen.refresh_size
        list_width = (screen.width * 0.35).to_i
        detail_width = screen.width - list_width

        @list_view = Views::ContactList.new(
          screen,
          x: 0,
          y: 1,
          width: list_width,
          height: screen.height - 2
        )

        @detail_view = Views::DetailPanel.new(
          screen,
          x: list_width,
          y: 1,
          width: detail_width,
          height: screen.height - 2
        )

        @status_bar = Views::StatusBar.new(screen, y: screen.height - 1)
        @status_bar.file_name = File.basename(contact_book.file_path)

        refresh_contacts
      end

      def render
        if @mode == :duplicates && @duplicates_view
          @duplicates_view.render
        else
          draw_header
          list_view.render
          detail_view.render
          @edit_modal&.render
          status_bar.render
        end
        $stdout.flush
      end

      def draw_header
        title = " VCF CLI - #{File.basename(contact_book.file_path)} (#{contact_book.size} contacts)"
        modified = contact_book.modified? ? " [modified]" : ""
        help = "[?] Help "

        header = screen.pastel.on_blue.white(
          screen.pad_right("#{title}#{modified}", screen.width - help.length) + help
        )
        screen.print_at(0, 0, header)
      end

      def refresh_contacts
        filtered = contact_book.search(filter)
        list_view.contacts = filtered
        list_view.filter = filter
        update_detail_view
      end

      def update_detail_view
        detail_view.contact = list_view.selected_contact
      end

      def handle_input
        key = input.read_key
        return unless key

        case mode
        when :normal
          handle_normal_mode(key)
        when :search
          handle_search_mode(key)
        when :edit
          handle_edit_mode(key)
        when :confirm_delete
          handle_confirm_delete(key)
        when :confirm_quit
          handle_confirm_quit(key)
        when :duplicates
          handle_duplicates_mode(key)
        end

        render
      end

      def handle_normal_mode(key)
        case key
        when :up, "k"
          list_view.move_selection(-1)
          update_detail_view
        when :down, "j"
          list_view.move_selection(1)
          update_detail_view
        when :page_up, :ctrl_u
          list_view.page_up
          update_detail_view
        when :page_down, :ctrl_d
          list_view.page_down
          update_detail_view
        when :top
          list_view.go_to_top
          update_detail_view
        when "G"
          list_view.go_to_bottom
          update_detail_view
        when "/"
          enter_search_mode
        when "E", "e"
          edit_contact
        when "D", "d"
          enter_delete_mode
        when "S", "s"
          save_contacts
        when "M", "m"
          find_duplicates
        when "q"
          quit_or_confirm
        when "?"
          show_help
        end
      end

      def handle_search_mode(key)
        case key
        when :escape
          exit_search_mode(clear: true)
        when :enter
          exit_search_mode(clear: false)
        when :backspace
          @filter = filter[0...-1]
          refresh_contacts
          list_view.update_filter(filter)
        when String
          if key.match?(/[[:print:]]/) && key.length == 1
            @filter += key
            refresh_contacts
            list_view.update_filter(filter)
          end
        end
        status_bar.mode = :search
      end

      def handle_confirm_delete(key)
        case key
        when "y", "Y"
          perform_delete
          @mode = :normal
          status_bar.mode = :normal
        when "n", "N", :escape
          @mode = :normal
          status_bar.mode = :normal
          status_bar.show_message("Delete cancelled")
        end
      end

      def handle_confirm_quit(key)
        case key
        when "y", "Y"
          @running = false
        when "n", "N", :escape
          @mode = :normal
          status_bar.mode = :normal
          status_bar.show_message("Quit cancelled")
        when "s", "S"
          save_contacts
          @running = false
        end
      end

      def enter_search_mode
        @mode = :search
        status_bar.mode = :search
        input.mode = :search
      end

      def exit_search_mode(clear:)
        @mode = :normal
        status_bar.mode = :normal
        input.mode = :normal
        if clear
          @filter = ""
          refresh_contacts
          list_view.update_filter("")
        end
      end

      def enter_delete_mode
        contact = list_view.selected_contact
        return unless contact

        @mode = :confirm_delete
        status_bar.mode = :confirm
        status_bar.message = " Delete '#{contact.display_name}'? (y/n) "
      end

      def perform_delete
        contact = list_view.selected_contact
        return unless contact

        contact_book.delete(contact)
        refresh_contacts
        status_bar.modified = contact_book.modified?
        status_bar.show_message("Contact deleted")
      end

      def edit_contact
        contact = list_view.selected_contact
        return unless contact

        @edit_modal = Views::EditModal.new(screen, contact)
        @mode = :edit
      end

      def handle_edit_mode(key)
        return unless @edit_modal

        if @edit_modal.editing
          # In field editing mode
          case key
          when :escape
            @edit_modal.stop_editing
          when :enter
            @edit_modal.stop_editing
          when :left
            @edit_modal.move_cursor_left
          when :right
            @edit_modal.move_cursor_right
          when :backspace
            @edit_modal.delete_char
          when String
            @edit_modal.insert_char(key) if key.length == 1 && key.ord >= 32
          end
        else
          # In field navigation mode
          case key
          when :escape
            exit_edit_mode(save: false)
          when :enter
            @edit_modal.start_editing
          when "\t", :tab
            exit_edit_mode(save: true)
          when :up, "k"
            @edit_modal.move_up
          when :down, "j"
            @edit_modal.move_down
          end
        end

        @edit_modal.render if @edit_modal
      end

      def exit_edit_mode(save:)
        if save && @edit_modal
          @edit_modal.apply_changes
          contact_book.update(@edit_modal.contact)
          status_bar.modified = contact_book.modified?
          status_bar.show_message("Contact updated")
        end
        @edit_modal&.stop_editing
        @edit_modal = nil
        @mode = :normal
        refresh_contacts
      end

      def save_contacts
        begin
          contact_book.save
          status_bar.modified = false
          status_bar.show_message("Saved successfully!")
        rescue StandardError => e
          status_bar.show_message("Save failed: #{e.message}")
        end
      end

      def find_duplicates
        status_bar.show_message("Scanning for duplicates...")
        render

        finder = Services::DuplicateFinder.new(contact_book)
        groups = finder.find_duplicates

        @duplicates_view = Views::DuplicatesView.new(screen, duplicate_groups: groups)
        @duplicate_finder = finder
        @mode = :duplicates
      end

      def handle_duplicates_mode(key)
        return unless @duplicates_view

        case key
        when :escape
          exit_duplicates_mode
          return
        when :up, "k"
          @duplicates_view.move_group_up
        when :down, "j"
          @duplicates_view.move_group_down
        when :left, "h"
          @duplicates_view.move_contact_left
        when :right, "l"
          @duplicates_view.move_contact_right
        when :enter
          merge_duplicate_group
        when "s", "S"
          skip_duplicate_group
        end

        @duplicates_view&.render
      end

      def merge_duplicate_group
        return unless @duplicates_view && @duplicate_finder

        primary = @duplicates_view.primary_contact
        others = @duplicates_view.other_contacts

        return if primary.nil? || others.empty?

        others.each do |other|
          @duplicate_finder.merge_contacts(primary, other)
        end

        merged_count = others.size
        @duplicates_view.status_message = "Merged #{merged_count} contacts into #{primary.display_name}"
        @duplicates_view.remove_current_group

        status_bar.modified = contact_book.modified?

        if @duplicates_view.duplicate_groups.empty?
          @duplicates_view.status_message = "All duplicates processed!"
          @duplicates_view.render
          $stdout.flush
          sleep 1
          exit_duplicates_mode
        end
      end

      def skip_duplicate_group
        return unless @duplicates_view

        @duplicates_view.status_message = "Skipped group"
        @duplicates_view.remove_current_group

        if @duplicates_view.duplicate_groups.empty?
          @duplicates_view.status_message = "All duplicates processed!"
          @duplicates_view.render
          $stdout.flush
          sleep 1
          exit_duplicates_mode
        end
      end

      def exit_duplicates_mode
        @duplicates_view = nil
        @duplicate_finder = nil
        @mode = :normal
        refresh_contacts
        status_bar.show_message("Duplicate finder closed")
      end

      def quit_or_confirm
        if contact_book.modified?
          @mode = :confirm_quit
          status_bar.mode = :confirm
          status_bar.message = " Unsaved changes! Save and quit? (y)es / (n)o / (s)ave first "
        else
          @running = false
        end
      end

      def show_help
        screen.clear
        help_text = <<~HELP
          ┌─────────────────────────────────────────────────────────────┐
          │                    VCF CLI - Help                          │
          ├─────────────────────────────────────────────────────────────┤
          │  Navigation:                                                │
          │    j / ↓        Move down                                  │
          │    k / ↑        Move up                                    │
          │    gg           Go to top                                  │
          │    G            Go to bottom                               │
          │    Ctrl+d       Page down                                  │
          │    Ctrl+u       Page up                                    │
          │                                                             │
          │  Actions:                                                   │
          │    /            Search/filter contacts                     │
          │    E            Edit selected contact                      │
          │    D            Delete selected contact                    │
          │    M            Find & merge duplicates                    │
          │    S            Save changes                               │
          │    q            Quit                                       │
          │    ?            Show this help                             │
          │                                                             │
          │  Duplicate Finder:                                          │
          │    j/k          Navigate groups                            │
          │    h/l          Select primary contact                     │
          │    Enter        Merge selected group                       │
          │    s            Skip group                                 │
          │    Escape       Exit duplicate finder                      │
          │                                                             │
          └─────────────────────────────────────────────────────────────┘

          Press any key to continue...
        HELP

        screen.print_at(0, 0, help_text)
        $stdout.flush
        input.read_key
      end
    end
  end
end
