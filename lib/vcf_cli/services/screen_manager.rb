# frozen_string_literal: true

require "tty-cursor"
require "tty-screen"
require "pastel"

module VcfCli
  module Services
    class ScreenManager
      attr_reader :width, :height, :cursor, :pastel

      def initialize
        @cursor = TTY::Cursor
        @pastel = Pastel.new
        @width = TTY::Screen.width
        @height = TTY::Screen.height
      end

      def setup
        # Hide cursor and enter alternate screen
        print cursor.hide
        print "\e[?1049h" # Enter alternate screen buffer
        clear
      end

      def teardown
        # Show cursor and exit alternate screen
        print "\e[?1049l" # Exit alternate screen buffer
        print cursor.show
      end

      def refresh_size
        @width = TTY::Screen.width
        @height = TTY::Screen.height
      end

      def clear
        print cursor.clear_screen
        print cursor.move_to(0, 0)
      end

      def move_to(x, y)
        print cursor.move_to(x, y)
      end

      def print_at(x, y, text)
        print cursor.move_to(x, y)
        print text
      end

      def draw_box(x, y, width, height, title: nil, border_color: nil)
        top_left = "┌"
        top_right = "┐"
        bottom_left = "└"
        bottom_right = "┘"
        horizontal = "─"
        vertical = "│"

        color = border_color ? ->(s) { pastel.send(border_color, s) } : ->(s) { s }

        # Top border
        top = if title
                title_str = " #{title} "
                remaining = width - 2 - title_str.length
                left_pad = remaining / 2
                right_pad = remaining - left_pad
                "#{top_left}#{horizontal * left_pad}#{title_str}#{horizontal * right_pad}#{top_right}"
              else
                "#{top_left}#{horizontal * (width - 2)}#{top_right}"
              end
        print_at(x, y, color.call(top))

        # Sides
        (1...height - 1).each do |row|
          print_at(x, y + row, color.call(vertical))
          print_at(x + width - 1, y + row, color.call(vertical))
        end

        # Bottom border
        print_at(x, y + height - 1, color.call("#{bottom_left}#{horizontal * (width - 2)}#{bottom_right}"))
      end

      def draw_horizontal_line(x, y, width, char: "─")
        print_at(x, y, char * width)
      end

      def draw_vertical_line(x, y, height, char: "│")
        height.times do |row|
          print_at(x, y + row, char)
        end
      end

      # Split character for T-junction
      def draw_t_junction(x, y, direction)
        char = case direction
               when :left then "┤"
               when :right then "├"
               when :up then "┴"
               when :down then "┬"
               end
        print_at(x, y, char)
      end

      def truncate(text, max_width, ellipsis: "…")
        return "" if text.nil?
        return text if text.length <= max_width

        text[0, max_width - 1] + ellipsis
      end

      def pad_right(text, width)
        text.to_s.ljust(width)[0, width]
      end

      def clear_line(y)
        print_at(0, y, " " * @width)
      end

      def clear_region(x, y, width, height)
        blank = " " * width
        height.times do |row|
          print_at(x, y + row, blank)
        end
      end
    end
  end
end
