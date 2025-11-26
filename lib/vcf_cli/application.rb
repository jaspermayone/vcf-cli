# frozen_string_literal: true

module VcfCli
  class Application
    attr_reader :file_path, :contact_book

    def initialize(file_path)
      @file_path = file_path
    end

    def run
      print "Loading contacts from #{file_path}... "
      $stdout.flush

      @contact_book = Models::ContactBook.new(file_path)
      @contact_book.load do |count|
        print "\rLoading contacts from #{file_path}... #{count}"
        $stdout.flush
      end

      puts "\rLoaded #{contact_book.size} contacts from #{file_path}#{" " * 10}"

      if contact_book.size == 0
        puts "No contacts found in file."
        return
      end

      controller = Controllers::ApplicationController.new(contact_book)
      controller.run
    rescue Interrupt
      puts "\nInterrupted."
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      exit 1
    end
  end
end
