# frozen_string_literal: true

module VcfCli
  module Views
    class StatusBar < BaseView
      attr_accessor :message, :mode, :modified, :file_name

      def initialize(screen, y:)
        super(screen, x: 0, y: y, width: screen.width, height: 1)
        @message = nil
        @mode = :normal
        @modified = false
        @file_name = ""
      end

      def render
        clear
        case mode
        when :search
          render_search_mode
        when :confirm
          render_confirm_mode
        else
          render_normal_mode
        end
      end

      def show_message(msg, duration: 2)
        @message = msg
        @message_expires = Time.now + duration
      end

      def clear_expired_message
        if @message_expires && Time.now > @message_expires
          @message = nil
          @message_expires = nil
        end
      end

      private

      def render_normal_mode
        # Left side: file info
        modified_indicator = modified ? pastel.red(" [+]") : ""
        file_info = " #{file_name}#{modified_indicator}"

        # Center: message or help
        help_text = message || "j/k:move  /:search  E:edit  D:delete  S:save  q:quit  ?:help"

        # Calculate layout
        left_width = file_info.length
        available = width - left_width - 2

        print_at(0, 0, pastel.on_black(file_info))
        print_at(left_width, 0, pastel.on_black.dim(" │ "))
        print_at(left_width + 3, 0, pastel.on_black.dim(truncate(help_text, available)))

        # Fill rest with background
        current_length = left_width + 3 + [help_text.length, available].min
        if current_length < width
          print_at(current_length, 0, pastel.on_black(" " * (width - current_length)))
        end
      end

      def render_search_mode
        search_prompt = " SEARCH: Type to filter, ESC to cancel"
        print_at(0, 0, pastel.on_yellow.black(pad_right(search_prompt, width)))
      end

      def render_confirm_mode
        confirm_prompt = message || " Confirm? (y/n)"
        print_at(0, 0, pastel.on_red.white(pad_right(confirm_prompt, width)))
      end
    end
  end
end
