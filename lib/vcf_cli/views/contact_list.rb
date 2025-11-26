# frozen_string_literal: true

module VcfCli
  module Views
    class ContactList < BaseView
      attr_accessor :contacts, :selected_index, :scroll_offset, :filter

      def initialize(screen, x:, y:, width:, height:)
        super(screen, x: x, y: y, width: width, height: height)
        @contacts = []
        @selected_index = 0
        @scroll_offset = 0
        @filter = ""
      end

      def render
        draw_border
        draw_filter_bar
        draw_contacts
        draw_scrollbar if contacts.size > visible_count
      end

      def visible_count
        height - 4  # Border top + filter bar + border bottom + status line space
      end

      def move_selection(delta)
        new_index = selected_index + delta
        new_index = [[new_index, 0].max, [contacts.size - 1, 0].max].min
        @selected_index = new_index
        adjust_scroll
      end

      def go_to_top
        @selected_index = 0
        @scroll_offset = 0
      end

      def go_to_bottom
        @selected_index = [contacts.size - 1, 0].max
        adjust_scroll
      end

      def page_down
        move_selection(visible_count)
      end

      def page_up
        move_selection(-visible_count)
      end

      def selected_contact
        return nil if contacts.empty?

        contacts[selected_index]
      end

      def update_filter(new_filter)
        @filter = new_filter
        @selected_index = 0
        @scroll_offset = 0
      end

      private

      def draw_border
        # Top border with title
        title = " Contacts (#{contacts.size}) "
        top_line = "┌" + "─" * ((width - 2 - title.length) / 2) + title +
                   "─" * (width - 2 - title.length - (width - 2 - title.length) / 2) + "┐"
        print_at(0, 0, pastel.cyan(top_line))

        # Side borders
        (1...height - 1).each do |row|
          print_at(0, row, pastel.cyan("│"))
          print_at(width - 1, row, pastel.cyan("│"))
        end

        # Bottom border
        print_at(0, height - 1, pastel.cyan("└" + "─" * (width - 2) + "┘"))
      end

      def draw_filter_bar
        filter_label = "/"
        filter_display = filter.empty? ? pastel.dim("type to filter...") : filter
        filter_line = " #{filter_label}#{filter_display}"
        # Clear line and draw
        print_at(1, 1, pad_right(filter_line, width - 2))

        # Separator
        print_at(0, 2, pastel.cyan("├" + "─" * (width - 2) + "┤"))
      end

      def draw_contacts
        visible_contacts.each_with_index do |contact, i|
          draw_contact_row(i + 3, contact, i + scroll_offset == selected_index)
        end

        # Clear empty rows
        (visible_contacts.size...visible_count).each do |i|
          print_at(1, i + 3, " " * (width - 2))
        end
      end

      def draw_contact_row(row, contact, selected)
        name = contact.display_name || "Unknown"
        photo_indicator = contact.has_photo ? "[P]" : "   "

        # Calculate available width for name
        name_width = width - 8  # 2 for borders, 1 for cursor, 4 for photo indicator, 1 padding

        display_name = truncate(name, name_width)
        cursor = selected ? ">" : " "

        line = if selected
                 pastel.on_blue.white(" #{cursor} #{pad_right(display_name, name_width)} #{photo_indicator}")
               else
                 " #{cursor} #{pad_right(display_name, name_width)} #{pastel.dim(photo_indicator)}"
               end

        print_at(1, row, line[0, width - 2])
      end

      def draw_scrollbar
        return if contacts.size <= visible_count

        scrollbar_height = visible_count
        thumb_size = [(visible_count.to_f / contacts.size * scrollbar_height).ceil, 1].max
        thumb_pos = (scroll_offset.to_f / [contacts.size - visible_count, 1].max * (scrollbar_height - thumb_size)).round

        scrollbar_height.times do |i|
          char = (i >= thumb_pos && i < thumb_pos + thumb_size) ? "█" : "░"
          print_at(width - 2, i + 3, pastel.dim(char))
        end
      end

      def visible_contacts
        contacts[scroll_offset, visible_count] || []
      end

      def adjust_scroll
        # Ensure selected item is visible
        if selected_index < scroll_offset
          @scroll_offset = selected_index
        elsif selected_index >= scroll_offset + visible_count
          @scroll_offset = selected_index - visible_count + 1
        end
      end
    end
  end
end
