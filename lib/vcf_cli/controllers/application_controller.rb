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
        @mode = :normal  # :normal, :search, :edit, :confirm_delete, :confirm_quit
        @filter = ""
        @running = true
        @pending_action = nil

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
        draw_header
        list_view.render
        detail_view.render
        status_bar.render
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
        when :confirm_delete
          handle_confirm_delete(key)
        when :confirm_quit
          handle_confirm_quit(key)
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
        when "E"
          edit_contact
        when "D"
          enter_delete_mode
        when "S"
          save_contacts
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

        # Simple edit mode - cycle through editable fields
        screen.teardown
        puts "\n--- Editing: #{contact.display_name} ---\n"
        puts "(Press Enter to keep current value, or type new value)\n\n"

        # Edit display name
        print "Name [#{contact.display_name}]: "
        new_name = $stdin.gets.chomp
        contact.display_name = new_name unless new_name.empty?

        # Edit primary phone
        current_phone = contact.primary_phone || ""
        print "Phone [#{current_phone}]: "
        new_phone = $stdin.gets.chomp
        unless new_phone.empty?
          if contact.phones.empty?
            contact.phones << { type: "CELL", value: new_phone }
          else
            contact.phones.first[:value] = new_phone
          end
        end

        # Edit primary email
        current_email = contact.primary_email || ""
        print "Email [#{current_email}]: "
        new_email = $stdin.gets.chomp
        unless new_email.empty?
          if contact.emails.empty?
            contact.emails << { type: "HOME", value: new_email }
          else
            contact.emails.first[:value] = new_email
          end
        end

        # Edit organization
        current_org = contact.organization || ""
        print "Organization [#{current_org}]: "
        new_org = $stdin.gets.chomp
        unless new_org.empty?
          if contact.organizations.empty?
            contact.organizations << new_org
          else
            contact.organizations[0] = new_org
          end
        end

        contact.mark_modified!
        contact_book.update(contact)

        puts "\nContact updated. Press Enter to continue..."
        $stdin.gets

        screen.setup
        refresh_contacts
        status_bar.modified = contact_book.modified?
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
          │    S            Save changes                               │
          │    q            Quit                                       │
          │    ?            Show this help                             │
          │                                                             │
          │  Search Mode:                                               │
          │    Type         Filter contacts                            │
          │    Enter        Apply filter                               │
          │    Escape       Clear filter and exit search               │
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
