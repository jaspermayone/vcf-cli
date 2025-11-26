# frozen_string_literal: true

module VcfCli
  module Parsers
    class VcfParser
      # Parse a VCF file and yield each vCard as a hash
      # Streams the file to handle large files efficiently
      def self.parse_file(file_path, &block)
        return enum_for(:parse_file, file_path) unless block_given?

        current_vcard_lines = []
        in_vcard = false
        pending_line = nil

        File.foreach(file_path) do |raw_line|
          line = raw_line.chomp

          # Handle line folding (continuation lines start with space or tab)
          if line =~ /^[ \t]/ && pending_line
            pending_line += line[1..]
            next
          end

          # Process the previous complete line
          if pending_line
            process_line = pending_line
            pending_line = line

            if process_line =~ /^BEGIN:VCARD/i
              in_vcard = true
              current_vcard_lines = [process_line]
            elsif process_line =~ /^END:VCARD/i && in_vcard
              current_vcard_lines << process_line
              contact_data = parse_vcard_lines(current_vcard_lines)
              yield contact_data if contact_data
              current_vcard_lines = []
              in_vcard = false
            elsif in_vcard
              current_vcard_lines << process_line
            end
          else
            pending_line = line
          end
        end

        # Process the last line
        if pending_line
          if pending_line =~ /^END:VCARD/i && in_vcard
            current_vcard_lines << pending_line
            contact_data = parse_vcard_lines(current_vcard_lines)
            yield contact_data if contact_data
          elsif in_vcard
            current_vcard_lines << pending_line
          end
        end
      end

      # Unfold vCard lines (handle line continuations)
      # Lines starting with space or tab are continuations of the previous line
      def self.unfold_lines(lines)
        unfolded = []

        lines.each do |line|
          # Remove trailing \r\n or \n
          line = line.chomp

          if line =~ /^[ \t]/ && !unfolded.empty?
            # Continuation line - append to previous (removing the leading whitespace)
            unfolded[-1] += line[1..]
          else
            unfolded << line
          end
        end

        unfolded
      end

      # Parse vCard lines into a hash
      def self.parse_vcard_lines(lines)
        data = {
          raw: lines.join("\n"),
          emails: [],
          phones: [],
          addresses: [],
          urls: [],
          organizations: [],
          notes: [],
          social_profiles: [],
          has_photo: false
        }

        lines.each do |line|
          line = line.strip
          next if line.empty?
          next if line =~ /^(BEGIN|END):VCARD/i

          # Handle property;params:value format
          # Be careful: value might contain colons (e.g., URLs, times)
          match = line.match(/^([^:]+):(.*)$/m)
          next unless match

          prop_part = match[1]
          value = match[2] || ""

          # Split property into name and parameters
          prop_parts = prop_part.split(";")
          property = prop_parts.first.upcase
          params = parse_params(prop_parts[1..] || [])

          case property
          when "VERSION"
            data[:version] = value.strip
          when "FN"
            data[:display_name] = decode_value(value)
          when "N"
            data[:structured_name] = parse_name(value)
          when "EMAIL"
            email_value = decode_value(value).strip
            # Validate email doesn't have obvious corruption
            if email_value =~ /@/ && !email_value.include?(" ")
              data[:emails] << { type: normalize_type(params["TYPE"]), value: email_value }
            end
          when "TEL"
            phone_value = decode_value(value).strip
            # Clean phone number - remove any non-phone characters that got attached
            phone_value = clean_phone(phone_value)
            data[:phones] << { type: normalize_type(params["TYPE"]), value: phone_value } unless phone_value.empty?
          when "ADR"
            data[:addresses] << { type: normalize_type(params["TYPE"]), value: parse_address(value) }
          when "ORG"
            org_value = decode_value(value).strip
            data[:organizations] << org_value unless org_value.empty?
          when "TITLE"
            data[:title] = decode_value(value).strip
          when "NOTE"
            data[:notes] << decode_value(value)
          when "URL"
            url_value = decode_value(value).strip
            data[:urls] << { type: normalize_type(params["TYPE"]), value: url_value } unless url_value.empty?
          when "PHOTO"
            data[:has_photo] = true
          when "BDAY"
            data[:birthday] = decode_value(value).strip
          when "X-SOCIALPROFILE", "IMPP"
            profile_type = params["TYPE"] || params["X-SERVICE-TYPE"] || extract_service_type(params) || "other"
            # For x-apple style, the username might be in x-user param
            profile_value = params["X-USER"] || decode_value(value).strip
            data[:social_profiles] << { type: normalize_type(profile_type), value: profile_value }
          when /^X-/
            # Store other X- properties for reference
            data[:x_properties] ||= []
            data[:x_properties] << { name: property, params: params, value: decode_value(value) }
          end
        end

        # Use structured name if no display name
        if data[:display_name].nil? || data[:display_name].empty?
          data[:display_name] = format_structured_name(data[:structured_name])
        end
        if data[:display_name].nil? || data[:display_name].empty?
          data[:display_name] = data[:emails].first&.dig(:value) || "Unknown"
        end

        data
      end

      # Legacy method for compatibility
      def self.parse_vcard(text)
        parse_vcard_lines(text.lines)
      end

      private

      def self.parse_params(parts)
        params = {}
        parts.each do |part|
          next if part.nil? || part.empty?

          if part.include?("=")
            key, value = part.split("=", 2)
            # Handle quoted values and multiple values
            value = value&.gsub('"', "")
            # TYPE can have multiple values like TYPE=WORK,VOICE
            if key.upcase == "TYPE" && params["TYPE"]
              params["TYPE"] = "#{params["TYPE"]},#{value}"
            else
              params[key.upcase] = value
            end
          else
            # Bare param like "HOME" or "WORK" (vCard 2.1 style)
            if params["TYPE"]
              params["TYPE"] = "#{params["TYPE"]},#{part}"
            else
              params["TYPE"] = part
            end
          end
        end
        params
      end

      def self.parse_name(value)
        # N field format: family;given;middle;prefix;suffix
        parts = value.split(";", -1).map { |p| decode_value(p).strip }
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
        ].compact.map(&:strip).reject(&:empty?)
        parts.empty? ? nil : parts.join(" ")
      end

      def self.parse_address(value)
        # ADR format: po_box;extended;street;city;region;postal_code;country
        parts = value.split(";", -1).map { |p| decode_value(p).strip }
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

        result = value.dup

        # Handle quoted-printable encoding (indicated by ENCODING=QUOTED-PRINTABLE)
        # Soft line breaks in QP are "=\n" - already handled by unfolding
        result = result.gsub(/=([0-9A-Fa-f]{2})/) { [$1].pack("H*") } if result.include?("=")

        # Handle escaped characters (vCard escaping)
        result.gsub!("\\n", "\n")
        result.gsub!("\\N", "\n")
        result.gsub!("\\,", ",")
        result.gsub!("\\;", ";")
        result.gsub!("\\:", ":")
        result.gsub!("\\\\", "\\")

        result
      end

      def self.normalize_type(type)
        return "other" if type.nil? || type.empty?

        # Take first type if multiple (e.g., "WORK,VOICE" -> "work")
        type.to_s.split(/[,;]/).first&.downcase&.strip || "other"
      end

      def self.clean_phone(value)
        # Phone numbers should only contain digits, spaces, dashes, parens, plus
        # If we see letters (other than 'x' for extension), truncate there
        if value =~ /^([+\d\s\-().x]+)/i
          $1.strip
        else
          value.gsub(/[^+\d\s\-().x]/i, "").strip
        end
      end

      def self.extract_service_type(params)
        # Look for service type in various param formats
        params.each do |key, value|
          return value if key =~ /SERVICE/i
        end
        nil
      end
    end
  end
end
