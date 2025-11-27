# frozen_string_literal: true

module VcfCli
  module Views
    class DuplicatesView < BaseView
      attr_reader :duplicate_groups, :selected_group_index, :selected_contact_index
      attr_accessor :status_message

      def initialize(screen, duplicate_groups:)
        super(screen)
        @duplicate_groups = duplicate_groups
        @selected_group_index = 0
        @selected_contact_index = 0
        @status_message = nil
        @scroll_offset = 0
      end

      def render
        screen.clear

        if duplicate_groups.empty?
          draw_empty_state
        else
          draw_header
          draw_group_list
          draw_contact_comparison
          draw_instructions
        end

        $stdout.flush
      end

      def move_group_up
        return if duplicate_groups.empty?

        @selected_group_index = [@selected_group_index - 1, 0].max
        @selected_contact_index = 0
        adjust_scroll
      end

      def move_group_down
        return if duplicate_groups.empty?

        @selected_group_index = [@selected_group_index + 1, duplicate_groups.size - 1].min
        @selected_contact_index = 0
        adjust_scroll
      end

      def move_contact_left
        return if current_group.nil?

        @selected_contact_index = [@selected_contact_index - 1, 0].max
      end

      def move_contact_right
        return if current_group.nil?

        max_idx = current_group.contacts.size - 1
        @selected_contact_index = [@selected_contact_index + 1, max_idx].min
      end

      def current_group
        return nil if duplicate_groups.empty?

        duplicate_groups[@selected_group_index]
      end

      def primary_contact
        return nil if current_group.nil?

        current_group.contacts[@selected_contact_index]
      end

      def other_contacts
        return [] if current_group.nil?

        current_group.contacts.reject.with_index { |_, i| i == @selected_contact_index }
      end

      def remove_current_group
        return if duplicate_groups.empty?

        @duplicate_groups.delete_at(@selected_group_index)
        @selected_group_index = [@selected_group_index, duplicate_groups.size - 1].min
        @selected_contact_index = 0
      end

      private

      def draw_empty_state
        message = "No duplicates found!"
        sub = "Press Escape to go back"

        center_y = height / 2

        print_at((width - message.length) / 2, center_y - 1, pastel.green.bold(message))
        print_at((width - sub.length) / 2, center_y + 1, pastel.dim(sub))
      end

      def draw_header
        title = " Duplicate Finder - #{duplicate_groups.size} groups found "
        header = pastel.on_magenta.white(title.center(width))
        print_at(0, 0, header)
      end

      def draw_group_list
        list_width = (width * 0.30).to_i
        list_height = height - 4

        # Draw border
        screen.draw_box(x, 2, list_width, list_height, title: "Groups", border_color: :magenta)

        # Draw groups
        visible_height = list_height - 2
        duplicate_groups.each_with_index do |group, i|
          next if i < @scroll_offset
          break if i >= @scroll_offset + visible_height

          row = 3 + (i - @scroll_offset)
          selected = i == @selected_group_index

          # Format group info
          primary_name = truncate(group.contacts.first.display_name, list_width - 8)
          count = "+#{group.contacts.size - 1}"
          score = "#{group.score}%"

          line = "#{primary_name} #{pastel.dim(count)}"

          if selected
            print_at(1, row, pastel.on_magenta.white(pad_right(line, list_width - 2)))
          else
            print_at(1, row, pad_right(line, list_width - 2))
          end
        end

        # Scroll indicators
        if @scroll_offset > 0
          print_at(list_width - 3, 3, pastel.yellow("^"))
        end
        if @scroll_offset + visible_height < duplicate_groups.size
          print_at(list_width - 3, 2 + list_height - 2, pastel.yellow("v"))
        end
      end

      def draw_contact_comparison
        return if current_group.nil?

        list_width = (width * 0.30).to_i
        panel_x = list_width + 1
        panel_width = width - list_width - 1
        panel_height = height - 4

        # Draw border
        screen.draw_box(panel_x, 2, panel_width, panel_height, title: "Compare", border_color: :cyan)

        # Draw match reasons
        reasons = current_group.match_reasons.join(" | ")
        print_at(panel_x + 2, 3, pastel.yellow("Match: #{reasons}"))

        # Draw contacts side by side
        contacts = current_group.contacts
        card_width = [(panel_width - 4) / [contacts.size, 3].min, 30].max
        contact_y = 5

        contacts.each_with_index do |contact, i|
          break if i >= 3  # Show max 3 contacts

          card_x = panel_x + 2 + (i * (card_width + 1))
          selected = i == @selected_contact_index

          draw_contact_card(contact, card_x, contact_y, card_width, panel_height - 6, selected)
        end

        # If more than 3 contacts
        if contacts.size > 3
          more_x = panel_x + 2 + (3 * (card_width + 1))
          print_at(more_x, contact_y + 2, pastel.dim("+#{contacts.size - 3} more"))
        end
      end

      def draw_contact_card(contact, card_x, card_y, card_width, card_height, selected)
        # Card header
        header_style = selected ? ->(s) { pastel.on_green.black(s) } : ->(s) { pastel.on_white.black(s) }
        header = selected ? " PRIMARY " : " Contact "
        print_at(card_x, card_y, header_style.call(header.center(card_width)))

        # Name
        name = truncate(contact.display_name || "Unknown", card_width - 2)
        name_style = selected ? pastel.green.bold(name) : pastel.white(name)
        print_at(card_x, card_y + 1, name_style)

        # Details
        details = [
          { icon: "", value: contact.primary_phone },
          { icon: "", value: contact.primary_email },
          { icon: "", value: contact.organization }
        ]

        row = card_y + 3
        details.each do |detail|
          next if detail[:value].nil? || detail[:value].empty?
          break if row >= card_y + card_height - 1

          text = truncate("#{detail[:icon]} #{detail[:value]}", card_width - 2)
          print_at(card_x, row, pastel.dim(text))
          row += 1
        end

        # Show count of additional data
        extras = []
        extras << "#{contact.emails.size} emails" if contact.emails.size > 1
        extras << "#{contact.phones.size} phones" if contact.phones.size > 1
        extras << "#{contact.addresses.size} addrs" if contact.addresses.size > 0

        if extras.any? && row < card_y + card_height - 1
          print_at(card_x, row, pastel.dark.white(extras.join(", ")))
        end

        # Selection indicator
        if selected
          print_at(card_x + card_width - 2, card_y, pastel.green("*"))
        end
      end

      def draw_instructions
        if @status_message
          msg = " #{@status_message} "
          print_at((width - msg.length) / 2, height - 1, pastel.on_green.black(msg))
        else
          instructions = "j/k:groups | h/l:select primary | Enter:merge | s:skip | Esc:exit"
          print_at((width - instructions.length) / 2, height - 1, pastel.dim(instructions))
        end
      end

      def adjust_scroll
        visible_height = height - 6
        if @selected_group_index < @scroll_offset
          @scroll_offset = @selected_group_index
        elsif @selected_group_index >= @scroll_offset + visible_height
          @scroll_offset = @selected_group_index - visible_height + 1
        end
      end
    end
  end
end
