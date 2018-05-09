require "ripper"
require "graphviz"
require "open3"
require "base64"

module Events
  # All Ripper events
  #
  # From Ruby 2.4.2.
  #
  # For each event:
  #
  # - description
  # - examples
  # - arguments
  def get_all_ripper_data
  {
    :BEGIN => {},
    :CHAR => {},
    :END => {},
    :__end__ => {},
    :alias => {},
    :alias_error => {},
    :aref => {},
    :aref_field => {},
    :arg_ambiguous => {},
    :arg_paren => {},
    :args_add => {},
    :args_add_block => {},
    :args_add_star => {},
    :args_new => {},
    :array => {},
    :assign => {},
    :assign_error => {},
    :assoc_new => {},
    :assoc_splat => {},
    :assoclist_from_args => {},
    :backref => {},
    :backtick => {},
    :bare_assoc_hash => {},
    :begin => {},
    :binary => {
      description: "An operator with left-hand side and right-hand side",
      examples: ["1 + 1"],
      arguments: [:lhs, :operator, :rhs]
    },
    :block_var => {},
    :block_var_add_block => {},
    :block_var_add_star => {},
    :blockarg => {},
    :bodystmt => {},
    :brace_block => {},
    :break => {},
    :call => {},
    :case => {},
    :class => {},
    :class_name_error => {},
    :comma => {},
    :command => {},
    :command_call => {},
    :comment => {},
    :const => {},
    :const_path_field => {},
    :const_path_ref => {},
    :const_ref => {},
    :cvar => {},
    :def => {},
    :defined => {},
    :defs => {},
    :do_block => {},
    :dot2 => {},
    :dot3 => {},
    :dyna_symbol => {},
    :else => {},
    :elsif => {},
    :embdoc => {},
    :embdoc_beg => {},
    :embdoc_end => {},
    :embexpr_beg => {},
    :embexpr_end => {},
    :embvar => {},
    :ensure => {},
    :excessed_comma => {},
    :fcall => {},
    :field => {},
    :float => {},
    :for => {},
    :gvar => {},
    :hash => {},
    :heredoc_beg => {},
    :heredoc_dedent => {},
    :heredoc_end => {},
    :ident => {},
    :if => {},
    :if_mod => {},
    :ifop => {},
    :ignored_nl => {},
    :imaginary => {},
    :int => {
      description: "An integer literal",
      examples: ["100"],
      arguments: [:literal, :position]
    },
    :ivar => {},
    :kw => {},
    :label => {},
    :label_end => {},
    :lambda => {},
    :lbrace => {},
    :lbracket => {},
    :lparen => {},
    :magic_comment => {},
    :massign => {},
    :method_add_arg => {},
    :method_add_block => {},
    :mlhs_add => {},
    :mlhs_add_star => {},
    :mlhs_new => {},
    :mlhs_paren => {},
    :module => {},
    :mrhs_add => {},
    :mrhs_add_star => {},
    :mrhs_new => {},
    :mrhs_new_from_args => {},
    :next => {},
    :nl => {},
    :op => {},
    :opassign => {},
    :operator_ambiguous => {},
    :param_error => {},
    :params => {},
    :paren => {},
    :parse_error => {},
    :period => {},
    :program => {
      description: "Top-level node for all parsed code",
      examples: [""],
      arguments: [:expressions]
    },
    :qsymbols_add => {},
    :qsymbols_beg => {},
    :qsymbols_new => {},
    :qwords_add => {},
    :qwords_beg => {},
    :qwords_new => {},
    :rational => {},
    :rbrace => {},
    :rbracket => {},
    :redo => {},
    :regexp_add => {},
    :regexp_beg => {},
    :regexp_end => {},
    :regexp_literal => {},
    :regexp_new => {},
    :rescue => {},
    :rescue_mod => {},
    :rest_param => {},
    :retry => {},
    :return => {},
    :return0 => {
      description: "A return statement with no arguments",
      examples: ["def a; return; end;"],
      arguments: [],
    },
    :rparen => {},
    :sclass => {},
    :semicolon => {},
    :sp => {},
    :stmts_add => {},
    :stmts_new => {},
    :string_add => {},
    :string_concat => {},
    :string_content => {},
    :string_dvar => {},
    :string_embexpr => {},
    :string_literal => {},
    :super => {},
    :symbeg => {},
    :symbol => {},
    :symbol_literal => {},
    :symbols_add => {},
    :symbols_beg => {},
    :symbols_new => {},
    :tlambda => {},
    :tlambeg => {},
    :top_const_field => {},
    :top_const_ref => {},
    :tstring_beg => {},
    :tstring_content => {},
    :tstring_end => {},
    :unary => {},
    :undef => {},
    :unless => {},
    :unless_mod => {},
    :until => {},
    :until_mod => {},
    :var_alias => {},
    :var_field => {},
    :var_ref => {},
    :vcall => {},
    :void_stmt => {
      description: "A filler node for blank statements, such as empty method bodies",
      examples: ["def a; end", "-> { } "],
      arguments: [],
    },
    :when => {},
    :while => {},
    :while_mod => {},
    :word_add => {},
    :word_new => {},
    :words_add => {},
    :words_beg => {},
    :words_new => {},
    :words_sep => {},
    :xstring_add => {},
    :xstring_literal => {},
    :xstring_new => {},
    :yield => {},
    :yield0 => {},
    :zsuper => {},
  }
  end

  # HTML preview of Ruby sexp_raw
  def render_preview(ruby_code)
    linked_sexp = link_sexp(Ripper.sexp_raw(ruby_code))
    "<code>Ripper.sexp_raw(#{ruby_code.inspect}) # => #{linked_sexp}</code>"
  end

  def link_sexp(sexp)
    case sexp
    when Symbol
      "<a href='##{sexp.to_s.sub("@", "")}'>#{sexp.inspect}</a>"
    when Array
      "[#{sexp.map { |e| link_sexp(e) }.join(", ")}]"
    else
      sexp.inspect
    end
  end

  # Returns Base64 image data
  def render_graphviz_png_data(ruby_code)
    sexp = Ripper.sexp_raw(ruby_code)
    graph = Graphviz::Graph.new
    add_children(graph, sexp)
    dot = graph.to_dot
    data = nil
    Open3.popen3("dot", "-Tpng") do |stdin, stdout, stderr, thd|
      stdin.puts(dot)
      stdin.close
      # err = stderr.gets(nil)
      # if err
      #   warn(err)
      # end
      data = stdout.gets(nil)
    end
    Base64.encode64(data)
  end

  # Add the Ruby sexp to the Graphviz node
  def add_children(node, sexp)
    if sexp
      if (!sexp.is_a?(Array)) || (sexp.is_a?(Array) && sexp.first.is_a?(Symbol))
        name, *children = sexp
        child_node = node.add_node(label: name.inspect)
        if children.any?
          children.each { |c| add_children(child_node, c) }
        end
      else
        child_node = node.add_node(label: "[...]")
        sexp.each { |c| add_children(child_node, c) }
      end
    else
      node.add_node(label: "nil")
    end
  end
end
