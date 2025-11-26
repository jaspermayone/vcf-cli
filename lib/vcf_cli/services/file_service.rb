# frozen_string_literal: true

require "fileutils"

module VcfCli
  module Services
    class FileService
      MAX_BACKUPS = 5

      def self.save(contact_book, file_path, backup: true)
        # Create backup before saving
        create_backup(file_path) if backup && File.exist?(file_path)

        # Write contacts to file
        File.open(file_path, "w") do |f|
          contact_book.each do |contact|
            next if contact.deleted

            f.puts contact.to_vcard
            f.puts # Blank line between contacts
          end
        end

        # Cleanup old backups
        cleanup_old_backups(file_path)

        true
      rescue StandardError => e
        raise VcfCli::Error, "Failed to save file: #{e.message}"
      end

      def self.create_backup(file_path)
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        backup_path = "#{file_path}.#{timestamp}.bak"
        FileUtils.cp(file_path, backup_path)
        backup_path
      end

      def self.cleanup_old_backups(file_path, keep: MAX_BACKUPS)
        backups = Dir.glob("#{file_path}.*.bak").sort
        return if backups.size <= keep

        backups[0..-(keep + 1)].each do |backup|
          File.delete(backup)
        end
      end

      def self.list_backups(file_path)
        Dir.glob("#{file_path}.*.bak").sort.reverse
      end

      def self.restore_backup(backup_path, target_path)
        FileUtils.cp(backup_path, target_path)
      end
    end
  end
end
