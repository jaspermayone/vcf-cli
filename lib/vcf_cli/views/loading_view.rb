# frozen_string_literal: true

module VcfCli
  module Views
    class LoadingView < BaseView
      SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"].freeze

      LOGO = <<~ASCII
        ╦  ╦╔═╗╔═╗  ╔═╗╦  ╦
        ╚╗╔╝║  ╠╣   ║  ║  ║
         ╚╝ ╚═╝╚    ╚═╝╩═╝╩
      ASCII

      CONTACT_ICON = <<~ASCII
           ┌─────┐
           │ ◉ ◉ │
           │  ▽  │
           └──┬──┘
            ┌─┴─┐
           ┌┴───┴┐
           └─────┘
      ASCII

      attr_accessor :count, :file_path, :status_message

      def initialize(screen, file_path:)
        super(screen)
        @file_path = File.basename(file_path)
        @count = 0
        @frame = 0
        @status_message = "Initializing..."
        @start_time = Time.now
        @particles = generate_particles
      end

      def render
        screen.clear
        @frame = (@frame + 1) % SPINNER_FRAMES.length

        center_y = height / 2 - 8

        # Draw decorative border
        draw_border

        # Draw logo centered
        draw_logo(center_y)

        # Draw contact icon with animation
        draw_contact_icon(center_y + 5)

        # Draw spinner and status
        draw_spinner(center_y + 13)

        # Draw progress info
        draw_progress(center_y + 15)

        # Draw progress bar
        draw_progress_bar(center_y + 17)

        # Draw footer
        draw_footer

        # Animate particles
        draw_particles

        $stdout.flush
      end

      def advance_frame
        @frame = (@frame + 1) % SPINNER_FRAMES.length
        update_particles
      end

      private

      def draw_border
        # Draw corner decorations
        corner_art = "●"

        # Top corners
        print_at(2, 1, pastel.green(corner_art))
        print_at(width - 3, 1, pastel.green(corner_art))

        # Bottom corners
        print_at(2, height - 2, pastel.green(corner_art))
        print_at(width - 3, height - 2, pastel.green(corner_art))

        # Draw subtle border lines
        horizontal = "─" * (width - 8)
        print_at(4, 1, pastel.dark.green(horizontal))
        print_at(4, height - 2, pastel.dark.green(horizontal))
      end

      def draw_logo(y_offset)
        logo_lines = LOGO.lines.map(&:chomp)
        logo_width = logo_lines.map(&:length).max
        start_x = (width - logo_width) / 2

        logo_lines.each_with_index do |line, i|
          # Gradient effect from bright to dim
          colored = case i
                    when 0 then pastel.bright_green(line)
                    when 1 then pastel.green(line)
                    else pastel.dark.green(line)
                    end
          print_at(start_x, y_offset + i, colored)
        end
      end

      def draw_contact_icon(y_offset)
        icon_lines = CONTACT_ICON.lines.map(&:chomp)
        icon_width = icon_lines.map(&:length).max
        start_x = (width - icon_width) / 2

        # Pulsing effect based on frame
        pulse_colors = [:green, :bright_green, :green, :dark]
        pulse_idx = (@frame / 2) % pulse_colors.length

        icon_lines.each_with_index do |line, i|
          color = pulse_colors[(pulse_idx + i) % pulse_colors.length]
          colored = if color == :dark
                      pastel.dark.green(line)
                    elsif color == :bright_green
                      pastel.bright_green(line)
                    else
                      pastel.green(line)
                    end
          print_at(start_x, y_offset + i, colored)
        end
      end

      def draw_spinner(y_offset)
        spinner = SPINNER_FRAMES[@frame]
        message = " #{@status_message}"

        full_text = "#{spinner}#{message}"
        start_x = (width - full_text.length) / 2

        print_at(start_x, y_offset, pastel.bright_green(spinner) + pastel.white(message))
      end

      def draw_progress(y_offset)
        elapsed = Time.now - @start_time
        rate = @count > 0 && elapsed > 0 ? (@count / elapsed).round : 0

        info = "📁 #{@file_path}  │  👤 #{@count} contacts  │  ⚡ #{rate}/sec"
        start_x = (width - visible_length(info)) / 2

        print_at(start_x, y_offset, pastel.cyan(info))
      end

      def draw_progress_bar(y_offset)
        bar_width = [width - 20, 40].min
        start_x = (width - bar_width) / 2

        # Animated fill pattern
        filled = (@frame * 2) % bar_width

        bar = ""
        bar_width.times do |i|
          if i <= filled
            # Wave pattern
            intensity = ((Math.sin((i + @frame) * 0.3) + 1) / 2 * 3).to_i
            char = ["░", "▒", "▓", "█"][intensity]
            bar += pastel.green(char)
          else
            bar += pastel.dark.white("░")
          end
        end

        print_at(start_x, y_offset, "#{pastel.green("[")}#{bar}#{pastel.green("]")}")
      end

      def draw_footer
        hint = "Loading your contacts..."
        dots = "." * ((@frame % 4) + 1)
        footer = "#{hint}#{dots.ljust(4)}"
        start_x = (width - footer.length) / 2

        print_at(start_x, height - 4, pastel.dark.white(footer))
      end

      def generate_particles
        8.times.map do
          {
            x: rand(width),
            y: rand(height),
            char: ["·", "•", "∘", "○"].sample,
            speed: rand(1..3)
          }
        end
      end

      def update_particles
        @particles.each do |p|
          p[:y] = (p[:y] + p[:speed]) % height
          p[:x] = (p[:x] + rand(-1..1)) % width
        end
      end

      def draw_particles
        @particles.each do |p|
          # Don't draw over the main content area
          next if p[:y] > height / 2 - 10 && p[:y] < height / 2 + 10
          next if p[:x] > width / 2 - 20 && p[:x] < width / 2 + 20

          print_at(p[:x], p[:y], pastel.dark.green(p[:char]))
        end
      end

      def visible_length(str)
        # Remove ANSI escape codes for length calculation
        str.gsub(/\e\[[0-9;]*m/, "").length
      end
    end
  end
end
