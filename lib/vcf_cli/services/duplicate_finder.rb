# frozen_string_literal: true

module VcfCli
  module Services
    class DuplicateFinder
      # Similarity thresholds
      NAME_THRESHOLD = 0.8
      EXACT_MATCH_SCORE = 100
      NAME_MATCH_SCORE = 50
      EMAIL_MATCH_SCORE = 80
      PHONE_MATCH_SCORE = 70

      DuplicateGroup = Struct.new(:contacts, :score, :match_reasons, keyword_init: true)

      def initialize(contact_book)
        @contact_book = contact_book
      end

      def find_duplicates
        contacts = @contact_book.active_contacts
        groups = []
        processed = Set.new

        contacts.each_with_index do |contact, idx|
          next if processed.include?(contact.id)

          matches = []
          contacts[(idx + 1)..].each do |other|
            next if processed.include?(other.id)

            score, reasons = calculate_similarity(contact, other)
            next if score.zero?

            matches << { contact: other, score: score, reasons: reasons }
          end

          next if matches.empty?

          # Sort by score descending
          matches.sort_by! { |m| -m[:score] }

          # Create group with the best matches
          group_contacts = [contact] + matches.map { |m| m[:contact] }
          group_score = matches.map { |m| m[:score] }.max
          all_reasons = matches.flat_map { |m| m[:reasons] }.uniq

          groups << DuplicateGroup.new(
            contacts: group_contacts,
            score: group_score,
            match_reasons: all_reasons
          )

          # Mark all contacts in this group as processed
          group_contacts.each { |c| processed.add(c.id) }
        end

        # Sort groups by score descending
        groups.sort_by { |g| -g.score }
      end

      def merge_contacts(primary, secondary)
        # Merge emails (avoid duplicates)
        secondary.emails.each do |email|
          unless primary.emails.any? { |e| normalize_email(e[:value]) == normalize_email(email[:value]) }
            primary.emails << email
          end
        end

        # Merge phones (avoid duplicates)
        secondary.phones.each do |phone|
          unless primary.phones.any? { |p| normalize_phone(p[:value]) == normalize_phone(phone[:value]) }
            primary.phones << phone
          end
        end

        # Merge addresses (avoid exact duplicates)
        secondary.addresses.each do |addr|
          unless primary.addresses.any? { |a| addresses_equal?(a, addr) }
            primary.addresses << addr
          end
        end

        # Merge organizations
        secondary.organizations.each do |org|
          unless primary.organizations.include?(org)
            primary.organizations << org
          end
        end

        # Merge notes
        secondary.notes.each do |note|
          unless primary.notes.include?(note)
            primary.notes << note
          end
        end

        # Merge URLs
        secondary.urls.each do |url|
          unless primary.urls.any? { |u| u[:value] == url[:value] }
            primary.urls << url
          end
        end

        # Take birthday if primary doesn't have one
        primary.birthday ||= secondary.birthday

        # Take title if primary doesn't have one
        primary.title ||= secondary.title

        # Mark contacts appropriately
        @contact_book.update(primary)
        @contact_book.delete(secondary)

        primary
      end

      private

      def calculate_similarity(contact1, contact2)
        score = 0
        reasons = []

        # Check for exact email match (strongest signal)
        if emails_match?(contact1, contact2)
          score += EMAIL_MATCH_SCORE
          reasons << "Same email"
        end

        # Check for phone match
        if phones_match?(contact1, contact2)
          score += PHONE_MATCH_SCORE
          reasons << "Same phone"
        end

        # Check for exact name match
        if exact_name_match?(contact1, contact2)
          score += EXACT_MATCH_SCORE
          reasons << "Exact name match"
        elsif fuzzy_name_match?(contact1, contact2)
          score += NAME_MATCH_SCORE
          reasons << "Similar name"
        end

        [score, reasons]
      end

      def exact_name_match?(c1, c2)
        normalize_name(c1.display_name) == normalize_name(c2.display_name)
      end

      def fuzzy_name_match?(c1, c2)
        name1 = normalize_name(c1.display_name)
        name2 = normalize_name(c2.display_name)

        return false if name1.empty? || name2.empty?

        # Check if names are similar using Levenshtein-like comparison
        similarity = string_similarity(name1, name2)
        return true if similarity >= NAME_THRESHOLD

        # Check if one name contains the other
        return true if name1.include?(name2) || name2.include?(name1)

        # Check first/last name match with different order
        parts1 = name1.split
        parts2 = name2.split

        return true if parts1.sort == parts2.sort

        false
      end

      def emails_match?(c1, c2)
        emails1 = c1.emails.map { |e| normalize_email(e[:value]) }.compact
        emails2 = c2.emails.map { |e| normalize_email(e[:value]) }.compact

        (emails1 & emails2).any?
      end

      def phones_match?(c1, c2)
        phones1 = c1.phones.map { |p| normalize_phone(p[:value]) }.compact
        phones2 = c2.phones.map { |p| normalize_phone(p[:value]) }.compact

        (phones1 & phones2).any?
      end

      def normalize_name(name)
        return "" if name.nil?

        name.downcase.gsub(/[^a-z0-9\s]/, "").strip
      end

      def normalize_email(email)
        return nil if email.nil? || email.empty?

        email.downcase.strip
      end

      def normalize_phone(phone)
        return nil if phone.nil? || phone.empty?

        # Keep only digits
        phone.gsub(/\D/, "")
      end

      def addresses_equal?(a1, a2)
        v1 = a1[:value] || a1
        v2 = a2[:value] || a2

        %i[street city region postal_code country].all? do |key|
          v1[key].to_s.downcase.strip == v2[key].to_s.downcase.strip
        end
      end

      def string_similarity(s1, s2)
        return 1.0 if s1 == s2
        return 0.0 if s1.empty? || s2.empty?

        # Simple similarity based on common bigrams
        bigrams1 = bigrams(s1)
        bigrams2 = bigrams(s2)

        return 0.0 if bigrams1.empty? || bigrams2.empty?

        intersection = (bigrams1 & bigrams2).size
        union = (bigrams1 | bigrams2).size

        intersection.to_f / union
      end

      def bigrams(str)
        return [] if str.length < 2

        (0...str.length - 1).map { |i| str[i, 2] }
      end
    end
  end
end
