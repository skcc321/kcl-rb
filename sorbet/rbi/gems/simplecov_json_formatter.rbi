# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: strict
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/simplecov_json_formatter/all/simplecov_json_formatter.rbi
#
# simplecov_json_formatter-0.1.4

module SimpleCovJSONFormatter
end
class SimpleCovJSONFormatter::SourceFileFormatter
  def branch_coverage; end
  def branches; end
  def format; end
  def initialize(source_file); end
  def line_coverage; end
  def lines; end
  def parse_branch(branch); end
  def parse_line(line); end
end
class SimpleCovJSONFormatter::ResultHashFormatter
  def format; end
  def format_files; end
  def format_groups; end
  def format_source_file(source_file); end
  def formatted_result; end
  def initialize(result); end
end
class SimpleCovJSONFormatter::ResultExporter
  def export; end
  def export_path; end
  def initialize(result_hash); end
  def json_result; end
end
module SimpleCov
end
module SimpleCov::Formatter
end
class SimpleCov::Formatter::JSONFormatter
  def export_formatted_result(result_hash); end
  def format(result); end
  def format_result(result); end
  def output_message(result); end
end
