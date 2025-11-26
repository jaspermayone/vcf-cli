# frozen_string_literal: true

module VcfCli
  module Views
    class DetailPanel < BaseView
      attr_accessor :contact

      FIELD_ORDER = %i[phones emails addresses organizations title birthday notes urls social_profiles].freeze

      FIELD_LABELS = {
        phones: "Phone",
        emails: "Email",
        addresses: "Address",
        organizations: "Organization",
        title: "Title",
        birthday: "Birthday",
        notes: "Notes",
        urls: "Website",
        social_profiles: "Social"
      }.freeze

      def initialize(screen, x:, y:, width:, height:)
        super(screen, x: x, y: y, width: width, height: height)
        @contact = nil
        @scroll_offset = 0
      end

      def render
        draw_border
        if contact
          draw_contact_details
        else
          draw_empty_state
        end
      end

      private

      def draw_border
        # Top border
        print_at(0, 0, pastel.cyan("┌" + "─" * (width - 2) + "┐"))

        # Side borders
        (1...height - 1).each do |row|
          print_at(0, row, pastel.cyan("│"))
          print_at(width - 1, row, pastel.cyan("│"))
        end

        # Bottom border
        print_at(0, height - 1, pastel.cyan("└" + "─" * (width - 2) + "┘"))
      end

      def draw_empty_state
        message = "No contact selected"
        col = (width - message.length) / 2
        row = height / 2
        print_at(col, row, pastel.dim(message))
      end

      def draw_contact_details
        content_width = width - 4
        row = 1

        # Name header
        name = contact.display_name || "Unknown"
        print_at(2, row, pastel.bold.white(truncate(name, content_width)))
        row += 1

        # Divider
        print_at(2, row, pastel.dim("─" * content_width))
        row += 2

        # Fields
        FIELD_ORDER.each do |field|
          break if row >= height - 2

          case field
          when :phones
            contact.phones.each do |phone|
              break if row >= height - 2

              row = draw_field(row, format_type(phone[:type], "Phone"), phone[:value], content_width)
            end
          when :emails
            contact.emails.each do |email|
              break if row >= height - 2

              row = draw_field(row, format_type(email[:type], "Email"), email[:value], content_width)
            end
          when :addresses
            contact.addresses.each do |addr|
              break if row >= height - 2

              address_text = contact.full_address(addr[:value] || addr)
              row = draw_field(row, format_type(addr[:type], "Address"), address_text, content_width)
            end
          when :organizations
            contact.organizations.each do |org|
              break if row >= height - 2

              row = draw_field(row, "Organization", org, content_width)
            end
          when :title
            if contact.title
              row = draw_field(row, "Title", contact.title, content_width)
            end
          when :birthday
            if contact.birthday
              row = draw_field(row, "Birthday", contact.birthday, content_width)
            end
          when :notes
            contact.notes.each do |note|
              break if row >= height - 2

              row = draw_field(row, "Notes", note, content_width)
            end
          when :urls
            contact.urls.each do |url|
              break if row >= height - 2

              row = draw_field(row, format_type(url[:type], "Website"), url[:value], content_width)
            end
          when :social_profiles
            (contact.social_profiles || []).each do |profile|
              break if row >= height - 2

              row = draw_field(row, format_type(profile[:type], "Social"), profile[:value], content_width)
            end
          end
        end

        # Photo indicator at bottom if space
        if contact.has_photo && row < height - 2
          row += 1
          print_at(2, row, pastel.yellow("[P] Has photo"))
        end

        # Clear remaining rows
        ((row + 1)...height - 1).each do |r|
          print_at(1, r, " " * (width - 2))
        end
      end

      def draw_field(row, label, value, content_width)
        return row if value.nil? || value.to_s.strip.empty?

        label_width = 12
        value_width = content_width - label_width - 2

        # Label
        print_at(2, row, pastel.cyan(pad_right("#{label}:", label_width)))

        # Value - handle multiline
        lines = wrap_text(value.to_s, value_width)
        lines.each_with_index do |line, i|
          break if row + i >= height - 2

          if i == 0
            print_at(2 + label_width, row, truncate(line, value_width))
          else
            print_at(2 + label_width, row + i, truncate(line, value_width))
          end
        end

        row + [lines.size, 1].max
      end

      def format_type(type, default)
        return default if type.nil? || type.to_s.strip.empty?

        type.to_s.split(/[,;]/).first&.capitalize || default
      end

      def wrap_text(text, width)
        return [""] if text.nil? || text.empty?

        lines = []
        text.split("\n").each do |paragraph|
          if paragraph.length <= width
            lines << paragraph
          else
            words = paragraph.split(/\s+/)
            current_line = ""
            words.each do |word|
              if current_line.empty?
                current_line = word
              elsif current_line.length + word.length + 1 <= width
                current_line += " #{word}"
              else
                lines << current_line
                current_line = word
              end
            end
            lines << current_line unless current_line.empty?
          end
        end
        lines.empty? ? [""] : lines
      end

      def pad_right(text, width)
        text.to_s.ljust(width)[0, width]
      end
    end
  end
end
