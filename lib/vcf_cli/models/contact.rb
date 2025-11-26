# frozen_string_literal: true

module VcfCli
  module Models
    class Contact
      attr_accessor :id, :display_name, :structured_name, :emails, :phones,
                    :addresses, :organizations, :title, :notes, :urls,
                    :birthday, :social_profiles, :has_photo, :raw, :version
      attr_accessor :deleted, :modified

      def initialize(data = {})
        @id = data[:id]
        @display_name = data[:display_name] || "Unknown"
        @structured_name = data[:structured_name] || {}
        @emails = data[:emails] || []
        @phones = data[:phones] || []
        @addresses = data[:addresses] || []
        @organizations = data[:organizations] || []
        @title = data[:title]
        @notes = data[:notes] || []
        @urls = data[:urls] || []
        @birthday = data[:birthday]
        @social_profiles = data[:social_profiles] || []
        @has_photo = data[:has_photo] || false
        @raw = data[:raw]
        @version = data[:version] || "3.0"
        @deleted = false
        @modified = false
      end

      def first_name
        structured_name[:given] || display_name.split.first
      end

      def last_name
        structured_name[:family] || display_name.split.last
      end

      def primary_email
        emails.first&.dig(:value)
      end

      def primary_phone
        phones.first&.dig(:value)
      end

      def organization
        organizations.first
      end

      def full_address(addr)
        return nil unless addr

        parts = [
          addr[:street],
          [addr[:city], addr[:region], addr[:postal_code]].compact.reject(&:empty?).join(", "),
          addr[:country]
        ].compact.reject(&:empty?)
        parts.join("\n")
      end

      def mark_modified!
        @modified = true
      end

      def mark_deleted!
        @deleted = true
      end

      # Generate vCard text from current data
      def to_vcard
        lines = ["BEGIN:VCARD", "VERSION:#{version}"]

        # Full name
        lines << "FN:#{escape_value(display_name)}"

        # Structured name
        if structured_name.any?
          n_parts = [
            structured_name[:family],
            structured_name[:given],
            structured_name[:middle],
            structured_name[:prefix],
            structured_name[:suffix]
          ].map { |p| escape_value(p.to_s) }
          lines << "N:#{n_parts.join(";")}"
        end

        # Emails
        emails.each do |email|
          type = email[:type]&.upcase || "OTHER"
          lines << "EMAIL;TYPE=#{type}:#{escape_value(email[:value])}"
        end

        # Phones
        phones.each do |phone|
          type = phone[:type]&.upcase || "OTHER"
          lines << "TEL;TYPE=#{type}:#{escape_value(phone[:value])}"
        end

        # Addresses
        addresses.each do |addr|
          type = addr[:type]&.upcase || "OTHER"
          addr_value = addr[:value] || addr
          adr_parts = [
            addr_value[:po_box],
            addr_value[:extended],
            addr_value[:street],
            addr_value[:city],
            addr_value[:region],
            addr_value[:postal_code],
            addr_value[:country]
          ].map { |p| escape_value(p.to_s) }
          lines << "ADR;TYPE=#{type}:#{adr_parts.join(";")}"
        end

        # Organization
        organizations.each do |org|
          lines << "ORG:#{escape_value(org)}"
        end

        # Title
        lines << "TITLE:#{escape_value(title)}" if title

        # Notes
        notes.each do |note|
          lines << "NOTE:#{escape_value(note)}"
        end

        # URLs
        urls.each do |url|
          type = url[:type]&.upcase || "OTHER"
          lines << "URL;TYPE=#{type}:#{escape_value(url[:value])}"
        end

        # Birthday
        lines << "BDAY:#{birthday}" if birthday

        lines << "END:VCARD"
        lines.join("\r\n")
      end

      private

      def escape_value(value)
        return "" if value.nil?

        value.to_s
             .gsub("\\", "\\\\")
             .gsub(",", "\\,")
             .gsub(";", "\\;")
             .gsub("\n", "\\n")
      end
    end
  end
end
