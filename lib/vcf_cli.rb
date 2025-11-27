# frozen_string_literal: true

require_relative "vcf_cli/version"

# Models
require_relative "vcf_cli/models/contact"
require_relative "vcf_cli/models/contact_book"
require_relative "vcf_cli/models/search_index"

# Parsers
require_relative "vcf_cli/parsers/vcf_parser"

# Services
require_relative "vcf_cli/services/screen_manager"
require_relative "vcf_cli/services/input_handler"
require_relative "vcf_cli/services/file_service"
require_relative "vcf_cli/services/duplicate_finder"

# Views
require_relative "vcf_cli/views/base_view"
require_relative "vcf_cli/views/loading_view"
require_relative "vcf_cli/views/contact_list"
require_relative "vcf_cli/views/detail_panel"
require_relative "vcf_cli/views/status_bar"
require_relative "vcf_cli/views/edit_modal"
require_relative "vcf_cli/views/duplicates_view"

# Controllers
require_relative "vcf_cli/controllers/application_controller"

# Main application
require_relative "vcf_cli/application"

module VcfCli
  class Error < StandardError; end
end
