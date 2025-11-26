# frozen_string_literal: true

module VcfCli
  module Views
    class BaseView
      attr_reader :screen, :x, :y, :width, :height

      def initialize(screen, x: 0, y: 0, width: nil, height: nil)
        @screen = screen
        @x = x
        @y = y
        @width = width || screen.width
        @height = height || screen.height
      end

      def render
        raise NotImplementedError, "Subclasses must implement render"
      end

      def clear
        screen.clear_region(x, y, width, height)
      end

      protected

      def pastel
        screen.pastel
      end

      def print_at(col, row, text)
        screen.print_at(x + col, y + row, text)
      end

      def truncate(text, max_width)
        screen.truncate(text, max_width)
      end

      def pad_right(text, width)
        screen.pad_right(text, width)
      end
    end
  end
end
