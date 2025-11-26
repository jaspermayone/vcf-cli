# frozen_string_literal: true

module VcfCli
  module Parsers
    class VcfParser
      # Parse a VCF file and yield each vCard as a hash
      def self.parse_file(file_path, &block)
        return enum_for(:parse_file, file_path) unless block_given?

        current_vcard = []
        in_vcard = false

        File.foreach(file_path) do |line|
          line = line.strip

          if line == "BEGIN:VCARD"
            in_vcard = true
            current_vcard = [line]
          elsif line == "END:VCARD" && in_vcard
            current_vcard << line
            vcard_text = current_vcard.join("\n")
            contact_data = parse_vcard(vcard_text)
            yield contact_data if contact_data
            current_vcard = []
            in_vcard = false
          elsif in_vcard
            current_vcard << line
          end
        end
      end

      # Parse a single vCard text block into a hash
      def self.parse_vcard(text)
        data = {
          raw: text,
          names: [],
          emails: [],
          phones: [],
          addresses: [],
          urls: [],
          organizations: [],
          notes: [],
          has_photo: false
        }

        text.each_line do |line|
          line = line.strip
          next if line.empty?

          # Handle property;params:value format
          if line.include?(":")
            prop_part, value = line.split(":", 2)
            prop_parts = prop_part.split(";")
            property = prop_parts.first.upcase
            params = parse_params(prop_parts[1..])

            case property
            when "VERSION"
              data[:version] = value
            when "FN"
              data[:display_name] = decode_value(value)
            when "N"
              data[:structured_name] = parse_name(decode_value(value))
            when "EMAIL"
              data[:emails] << { type: params["TYPE"] || "other", value: decode_value(value) }
            when "TEL"
              data[:phones] << { type: params["TYPE"] || "other", value: decode_value(value) }
            when "ADR"
              data[:addresses] << { type: params["TYPE"] || "other", value: parse_address(decode_value(value)) }
            when "ORG"
              data[:organizations] << decode_value(value)
            when "TITLE"
              data[:title] = decode_value(value)
            when "NOTE"
              data[:notes] << decode_value(value)
            when "URL"
              data[:urls] << { type: params["TYPE"] || "other", value: decode_value(value) }
            when "PHOTO"
              data[:has_photo] = true
            when "BDAY"
              data[:birthday] = decode_value(value)
            when "X-SOCIALPROFILE", "IMPP"
              data[:social_profiles] ||= []
              data[:social_profiles] << { type: params["TYPE"] || params["X-SERVICE-TYPE"] || "other", value: decode_value(value) }
            end
          end
        end

        # Use structured name if no display name
        data[:display_name] ||= format_structured_name(data[:structured_name]) if data[:structured_name]
        data[:display_name] ||= data[:emails].first&.dig(:value) || "Unknown"

        data
      end

      private

      def self.parse_params(parts)
        params = {}
        parts.each do |part|
          if part.include?("=")
            key, value = part.split("=", 2)
            params[key.upcase] = value&.gsub('"', "")
          else
            # Bare param like "HOME" or "WORK"
            params["TYPE"] = part
          end
        end
        params
      end

      def self.parse_name(value)
        parts = value.split(";")
        {
          family: parts[0],
          given: parts[1],
          middle: parts[2],
          prefix: parts[3],
          suffix: parts[4]
        }
      end

      def self.format_structured_name(name)
        return nil unless name

        parts = [
          name[:prefix],
          name[:given],
          name[:middle],
          name[:family],
          name[:suffix]
        ].compact.reject(&:empty?)
        parts.join(" ")
      end

      def self.parse_address(value)
        parts = value.split(";")
        {
          po_box: parts[0],
          extended: parts[1],
          street: parts[2],
          city: parts[3],
          region: parts[4],
          postal_code: parts[5],
          country: parts[6]
        }
      end

      def self.decode_value(value)
        return "" if value.nil?

        # Handle quoted-printable encoding
        if value.include?("=")
          value = value.gsub(/=([0-9A-Fa-f]{2})/) { [$1].pack("H*") }
        end

        # Handle escaped characters
        value.gsub("\\n", "\n")
             .gsub("\\,", ",")
             .gsub("\\;", ";")
             .gsub("\\\\", "\\")
      end
    end
  end
end
