# frozen_string_literal: true

module VcfCli
  class Application
    attr_reader :file_path, :contact_book

    def initialize(file_path)
      @file_path = file_path
    end

    def run
      @screen = Services::ScreenManager.new
      @screen.setup

      # Show loading screen
      loading_view = Views::LoadingView.new(@screen, file_path: file_path)
      loading_view.render

      @contact_book = Models::ContactBook.new(file_path)

      # Animation thread for smooth loading animation
      @loading = true
      animation_thread = Thread.new do
        while @loading
          loading_view.advance_frame
          loading_view.render
          sleep 0.08
        end
      end

      # Load contacts with progress updates
      @contact_book.load do |count|
        loading_view.count = count
        loading_view.status_message = "Reading contacts..."
      end

      loading_view.count = contact_book.size
      loading_view.status_message = "Finalizing..."
      loading_view.render
      sleep 0.3

      @loading = false
      animation_thread.join

      @screen.teardown

      if contact_book.size == 0
        puts "No contacts found in file."
        return
      end

      # Launch main application
      controller = Controllers::ApplicationController.new(contact_book)
      controller.run
    rescue Interrupt
      @loading = false
      @screen&.teardown
      puts "\nInterrupted."
    rescue StandardError => e
      @loading = false
      @screen&.teardown
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      exit 1
    end
  end
end
