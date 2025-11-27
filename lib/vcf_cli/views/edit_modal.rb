# frozen_string_literal: true

module VcfCli
  module Views
    class EditModal < BaseView
      FIELDS = [
        { key: :name, label: "Name" },
        { key: :phone, label: "Phone" },
        { key: :email, label: "Email" },
        { key: :organization, label: "Organization" }
      ].freeze

      attr_reader :contact, :field_index, :field_values, :cursor_pos
      attr_accessor :editing

      def initialize(screen, contact)
        modal_width = 60
        modal_height = FIELDS.size + 6
        modal_x = (screen.width - modal_width) / 2
        modal_y = (screen.height - modal_height) / 2

        super(screen, x: modal_x, y: modal_y, width: modal_width, height: modal_height)

        @contact = contact
        @field_index = 0
        @editing = false
        @cursor_pos = 0
        @field_values = extract_field_values
      end

      def render
        draw_background
        draw_border
        draw_title
        draw_fields
        draw_instructions
        position_cursor if @editing
      end

      def current_field
        FIELDS[@field_index][:key]
      end

      def current_value
        @field_values[current_field]
      end

      def current_value=(val)
        @field_values[current_field] = val
      end

      def move_up
        @field_index = (@field_index - 1) % FIELDS.size
        @cursor_pos = current_value.length
      end

      def move_down
        @field_index = (@field_index + 1) % FIELDS.size
        @cursor_pos = current_value.length
      end

      def start_editing
        @editing = true
        @cursor_pos = current_value.length
        print screen.cursor.show
      end

      def stop_editing
        @editing = false
        print screen.cursor.hide
      end

      def insert_char(char)
        val = current_value
        @field_values[current_field] = val[0, @cursor_pos] + char + val[@cursor_pos..]
        @cursor_pos += 1
      end

      def delete_char
        return if @cursor_pos == 0

        val = current_value
        @field_values[current_field] = val[0, @cursor_pos - 1] + val[@cursor_pos..]
        @cursor_pos -= 1
      end

      def move_cursor_left
        @cursor_pos = [@cursor_pos - 1, 0].max
      end

      def move_cursor_right
        @cursor_pos = [@cursor_pos + 1, current_value.length].min
      end

      def apply_changes
        contact.display_name = @field_values[:name] unless @field_values[:name].empty?

        unless @field_values[:phone].empty?
          if contact.phones.empty?
            contact.phones << { type: "CELL", value: @field_values[:phone] }
          else
            contact.phones.first[:value] = @field_values[:phone]
          end
        end

        unless @field_values[:email].empty?
          if contact.emails.empty?
            contact.emails << { type: "HOME", value: @field_values[:email] }
          else
            contact.emails.first[:value] = @field_values[:email]
          end
        end

        unless @field_values[:organization].empty?
          if contact.organizations.empty?
            contact.organizations << @field_values[:organization]
          else
            contact.organizations[0] = @field_values[:organization]
          end
        end

        contact.mark_modified!
      end

      private

      def extract_field_values
        {
          name: contact.display_name || "",
          phone: contact.primary_phone || "",
          email: contact.primary_email || "",
          organization: contact.organization || ""
        }
      end

      def draw_background
        blank = " " * width
        height.times do |row|
          print_at(0, row, blank)
        end
      end

      def draw_border
        screen.draw_box(x, y, width, height, title: "Edit Contact", border_color: :cyan)
      end

      def draw_title
        name = truncate(contact.display_name || "Unknown", width - 8)
        print_at(2, 1, pastel.bold.white(name))
        print_at(2, 2, pastel.dim("─" * (width - 4)))
      end

      def draw_fields
        label_width = 14
        value_width = width - label_width - 6

        FIELDS.each_with_index do |field, i|
          row = 3 + i
          selected = i == @field_index
          value = @field_values[field[:key]]

          # Label
          label = "#{field[:label]}:"
          if selected
            print_at(2, row, pastel.cyan.bold(label.ljust(label_width)))
          else
            print_at(2, row, pastel.dim(label.ljust(label_width)))
          end

          # Value field
          display_value = truncate(value, value_width)
          if selected
            if @editing
              # Show with cursor
              print_at(2 + label_width, row, pastel.on_blue(display_value.ljust(value_width)))
            else
              print_at(2 + label_width, row, pastel.inverse(display_value.ljust(value_width)))
            end
          else
            print_at(2 + label_width, row, display_value.ljust(value_width))
          end
        end
      end

      def draw_instructions
        row = height - 2
        if @editing
          instructions = "Type to edit | ←→:cursor | Enter:done | Esc:cancel"
        else
          instructions = "j/k:navigate | Enter:edit | Esc:cancel | Tab:save"
        end
        centered = instructions.center(width - 4)
        print_at(2, row, pastel.dim(centered))
      end

      def position_cursor
        label_width = 14
        cursor_x = x + 2 + label_width + [@cursor_pos, width - label_width - 6].min
        cursor_y = y + 3 + @field_index
        print screen.cursor.move_to(cursor_x, cursor_y)
      end
    end
  end
end
