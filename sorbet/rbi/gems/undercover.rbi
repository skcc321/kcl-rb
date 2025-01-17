# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: true
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/undercover/all/undercover.rbi
#
# undercover-0.4.4

module Undercover
end
class Undercover::LcovParseError < StandardError
end
class Undercover::LcovParser
  def coverage(filepath); end
  def initialize(lcov_io); end
  def io; end
  def parse; end
  def parse_line(line); end
  def self.parse(lcov_report_path); end
  def source_files; end
end
class Undercover::Result
  def count_covered_branches(line_number); end
  def coverage; end
  def coverage_f; end
  def file_path; end
  def file_path_with_lines; end
  def first_line(*args, &block); end
  def flag; end
  def flagged?; end
  def initialize(node, file_cov, file_path); end
  def inspect; end
  def last_line(*args, &block); end
  def name(*args, &block); end
  def node; end
  def pretty_print; end
  def pretty_print_lines; end
  def to_s; end
  def uncovered?(line_no); end
  extend Forwardable
end
module Undercover::CLI
  def self.changeset(opts); end
  def self.run(args); end
  def self.run_report(opts); end
  def self.syntax_version(version); end
end
class Undercover::Changeset
  def <=>(*args, &block); end
  def compare_base; end
  def compare_base_obj; end
  def each(*args, &block); end
  def each_changed_line; end
  def file_paths; end
  def files; end
  def full_diff; end
  def head; end
  def initialize(dir, compare_base = nil); end
  def last_modified; end
  def repo; end
  def update; end
  def validate(lcov_report_path); end
  extend Forwardable
  include Enumerable
end
class Undercover::Formatter
  def formatted_warnings; end
  def initialize(results); end
  def pad_size; end
  def success; end
  def to_s; end
  def warnings_header; end
end
class Undercover::Options
  def args_from_options_file(path); end
  def build_opts(args); end
  def compare; end
  def compare=(arg0); end
  def compare_option(parser); end
  def git_dir; end
  def git_dir=(arg0); end
  def git_dir_option(parser); end
  def guess_lcov_path; end
  def initialize; end
  def lcov; end
  def lcov=(arg0); end
  def lcov_path_option(parser); end
  def parse(args); end
  def path; end
  def path=(arg0); end
  def project_options; end
  def project_options_file; end
  def project_path_option(parser); end
  def ruby_syntax_option(parser); end
  def syntax_version; end
  def syntax_version=(arg0); end
end
class Undercover::Report
  def all_results; end
  def build; end
  def build_warnings; end
  def changeset; end
  def code_dir; end
  def flagged_results; end
  def initialize(changeset, opts); end
  def inspect; end
  def lcov; end
  def load_and_parse_file(filepath); end
  def loaded_files; end
  def results; end
  def to_s; end
  def validate(*args, &block); end
  extend Forwardable
end
module KclDemo
end
