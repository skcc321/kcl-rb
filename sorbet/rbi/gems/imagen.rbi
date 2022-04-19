# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: strict
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/imagen/all/imagen.rbi
#
# imagen-0.1.8

module Imagen
  def self.from_local(dir); end
  def self.from_remote(repo_url); end
  def self.parser_version; end
  def self.parser_version=(arg0); end
end
module Imagen::AST
end
class Imagen::AST::Parser
  def initialize(parser_version = nil); end
  def parse(input, file = nil); end
  def parse_file(filename); end
  def parser; end
  def self.parse(input, file = nil); end
  def self.parse_file(filename); end
  def validate_version(parser_version); end
end
class Imagen::AST::Builder < Parser::Builders::Default
  def string_value(token); end
end
module Imagen::Node
end
class Imagen::Node::Base
  def ast_node; end
  def build_from_ast(ast_node); end
  def children; end
  def file_path; end
  def find_all(matcher, ret = nil); end
  def first_line; end
  def human_name; end
  def initialize; end
  def last_line; end
  def line_numbers; end
  def name; end
  def source; end
  def source_lines; end
  def source_lines_with_numbers; end
end
class Imagen::Node::Root < Imagen::Node::Base
  def build_from_dir(dir); end
  def build_from_file(path); end
  def dir; end
  def file_path; end
  def first_line; end
  def human_name; end
  def last_line; end
  def list_files; end
  def source; end
end
class Imagen::Node::Module < Imagen::Node::Base
  def build_from_ast(ast_node); end
  def human_name; end
end
class Imagen::Node::Class < Imagen::Node::Base
  def build_from_ast(ast_node); end
  def human_name; end
end
class Imagen::Node::CMethod < Imagen::Node::Base
  def build_from_ast(ast_node); end
  def human_name; end
end
class Imagen::Node::IMethod < Imagen::Node::Base
  def build_from_ast(ast_node); end
  def human_name; end
end
class Imagen::Node::Block < Imagen::Node::Base
  def args_list; end
  def build_from_ast(_ast_node); end
  def human_name; end
end
class Imagen::Visitor
  def current_root; end
  def file_path; end
  def root; end
  def self.traverse(ast, root); end
  def traverse(ast_node, parent); end
  def visit(ast_node, parent); end
end
class Imagen::GitError < StandardError
end
class Imagen::Clone
  def dir; end
  def initialize(repo_url, dirname); end
  def perform; end
  def repo_url; end
  def self.perform(repo_url, dir); end
end
class Imagen::RemoteBuilder
  def build; end
  def dir; end
  def initialize(repo_url); end
  def repo_url; end
  def teardown; end
end
