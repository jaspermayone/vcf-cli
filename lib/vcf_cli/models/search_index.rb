# frozen_string_literal: true

module VcfCli
  module Models
    class SearchIndex
      def initialize
        @name_index = {}
        @email_index = {}
        @phone_index = {}
        @org_index = {}
      end

      def add(contact)
        # Index by normalized name
        if contact.display_name
          normalized = normalize(contact.display_name)
          (@name_index[normalized] ||= Set.new) << contact.id
        end

        # Index by emails
        contact.emails.each do |email|
          normalized = normalize(email[:value])
          (@email_index[normalized] ||= Set.new) << contact.id
        end

        # Index by phones (digits only)
        contact.phones.each do |phone|
          normalized = phone[:value].to_s.gsub(/\D/, "")
          (@phone_index[normalized] ||= Set.new) << contact.id if normalized.length >= 3
        end

        # Index by organization
        contact.organizations.each do |org|
          normalized = normalize(org)
          (@org_index[normalized] ||= Set.new) << contact.id
        end
      end

      def update(contact)
        # Remove old entries and re-add
        remove(contact.id)
        add(contact)
      end

      def remove(contact_id)
        [@name_index, @email_index, @phone_index, @org_index].each do |index|
          index.each_value { |ids| ids.delete(contact_id) }
        end
      end

      def search(query)
        return Set.new if query.nil? || query.strip.empty?

        normalized_query = normalize(query)
        phone_query = query.gsub(/\D/, "")
        results = Set.new

        # Search names
        @name_index.each do |key, ids|
          results.merge(ids) if key.include?(normalized_query)
        end

        # Search emails
        @email_index.each do |key, ids|
          results.merge(ids) if key.include?(normalized_query)
        end

        # Search phones (if query looks like a phone number)
        if phone_query.length >= 3
          @phone_index.each do |key, ids|
            results.merge(ids) if key.include?(phone_query)
          end
        end

        # Search organizations
        @org_index.each do |key, ids|
          results.merge(ids) if key.include?(normalized_query)
        end

        results
      end

      private

      def normalize(text)
        return "" if text.nil?

        text.to_s.downcase.strip
      end
    end
  end
end
