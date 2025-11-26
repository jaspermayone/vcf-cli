# frozen_string_literal: true

module VcfCli
  module Models
    class ContactBook
      attr_reader :file_path, :contacts, :search_index

      def initialize(file_path)
        @file_path = file_path
        @contacts = []
        @search_index = SearchIndex.new
        @modified = false
      end

      def load(&progress_callback)
        @contacts = []
        id = 0

        Parsers::VcfParser.parse_file(@file_path) do |data|
          data[:id] = id
          contact = Contact.new(data)
          @contacts << contact
          @search_index.add(contact)
          id += 1
          progress_callback&.call(id) if id % 50 == 0
        end

        progress_callback&.call(id)
        self
      end

      def size
        active_contacts.size
      end

      def total_size
        @contacts.size
      end

      def active_contacts
        @contacts.reject(&:deleted)
      end

      def [](index)
        active_contacts[index]
      end

      def each(&block)
        active_contacts.each(&block)
      end

      def search(query)
        return active_contacts if query.nil? || query.empty?

        ids = @search_index.search(query)
        active_contacts.select { |c| ids.include?(c.id) }
      end

      def delete(contact)
        contact.mark_deleted!
        @modified = true
      end

      def update(contact)
        contact.mark_modified!
        @search_index.update(contact)
        @modified = true
      end

      def modified?
        @modified || @contacts.any?(&:modified) || @contacts.any?(&:deleted)
      end

      def deleted_count
        @contacts.count(&:deleted)
      end

      def modified_count
        @contacts.count(&:modified)
      end

      def save(backup: true)
        FileService.save(self, @file_path, backup: backup)
        reset_modification_flags
      end

      private

      def reset_modification_flags
        @modified = false
        @contacts.each do |c|
          c.modified = false
        end
        # Remove deleted contacts permanently after save
        @contacts.reject!(&:deleted)
      end
    end
  end
end
