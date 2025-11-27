# frozen_string_literal: true

require "tty-reader"

module VcfCli
  module Services
    class InputHandler
      attr_reader :reader
      attr_accessor :on_key, :mode

      # Key constants for vim-style navigation
      KEYS = {
        up: [:up, "k"],
        down: [:down, "j"],
        page_up: [:page_up, "ctrl_u"],
        page_down: [:page_down, "ctrl_d"],
        top: ["g"],         # gg sequence
        bottom: ["G"],
        search: ["/"],
        edit: ["E", "e"],
        delete: ["D", "d"],
        save: ["S", "s"],
        quit: ["q"],
        help: ["?"],
        enter: [:enter],
        escape: [:escape],
        backspace: [:backspace]
      }.freeze

      def initialize
        @reader = TTY::Reader.new(interrupt: :noop)
        @mode = :normal  # :normal, :search, :edit, :confirm
        @g_pressed = false  # For gg sequence
      end

      def read_key
        char = @reader.read_keypress

        # Handle gg sequence for go-to-top
        if @mode == :normal && @g_pressed
          @g_pressed = false
          return :top if char == "g"
          # If not g, process both keys
          # First was g, now handle current char
        end

        if @mode == :normal && char == "g"
          @g_pressed = true
          return nil  # Wait for next key
        end

        normalize_key(char)
      end

      def read_line(prompt: "", value: "")
        @reader.read_line(prompt, value: value)
      end

      private

      def normalize_key(char)
        return nil if char.nil?

        # Handle special keys from tty-reader
        case char
        when "\e[A", "\e[1;5A" then :up
        when "\e[B", "\e[1;5B" then :down
        when "\e[C" then :right
        when "\e[D" then :left
        when "\e[5~" then :page_up
        when "\e[6~" then :page_down
        when "\e[H", "\e[1~" then :home
        when "\e[F", "\e[4~" then :end
        when "\r", "\n" then :enter
        when "\e" then :escape
        when "\u007F", "\b" then :backspace
        when "\u0003" then :ctrl_c
        when "\u0004" then :ctrl_d
        when "\u0015" then :ctrl_u
        else
          char
        end
      end
    end
  end
end
