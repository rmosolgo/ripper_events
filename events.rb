require "ripper"
require "graphviz"
require "open3"
require "base64"
require "pp"
require "kramdown"

module Events
  class Event
    attr_reader :name, :description, :examples, :arguments
    def initialize(name:, description: nil, examples: [], lex_examples: [], arguments: [])
      @name = name
      @description = description && Kramdown::Document.new(description).to_html
      @examples = examples.map { |ex| Example.new(code: ex, type: :parser) }
      @examples += lex_examples.map { |ex| Example.new(code: ex, type: :lex) }

      @arguments = arguments
    end

    def documented?
      !!@description
    end
  end

  class Example
    attr_reader :rendered_code, :rendered_image
    def initialize(code:, type:)
      if type == :parser
        @rendered_code = render_preview(code)
        sexp = Ripper.sexp_raw(code)
        @rendered_image = %|<img src="data:image/png;base64,#{render_graphviz_png_data(sexp)}"/>|
      else
        @rendered_code = render_lex_preview(code)
        tokens = Ripper.lex(code)
        @rendered_image = %|<img src="data:image/png;base64,#{render_graphviz_png_data(tokens)}"/>|
      end
    end

    private
    # HTML preview of Ruby sexp_raw
    def render_preview(ruby_code)
      linked_sexp = pretty_sexp(Ripper.sexp_raw(ruby_code))
      "<pre>Ripper.sexp_raw(#{ruby_code.inspect})\n#{linked_sexp}</pre>"
    end

    # HTML preview of Ruby sexp_raw
    def render_lex_preview(ruby_code)
      linked_sexp = pretty_sexp(Ripper.lex(ruby_code))
      "<pre>Ripper.lex(#{ruby_code.inspect})\n#{linked_sexp}</pre>"
    end

    def pretty_sexp(sexp)
      linked_sexp = link_sexp(sexp)
      io = PP.pp(linked_sexp, StringIO.new)
      output = io.string
        .split("\n")
        .map { |l| "# #{l}" }
        .join("\n")
      output
    end

    class Link
      def initialize(name:)
        @name = name
        @link = "<a href='##{name.to_s.sub("@", "").sub(/^on_/, "")}'>#{name.inspect}</a>"
      end

      def pretty_print(pp)
        pp.text(@link)
      end
    end

    def link_sexp(sexp)
      case sexp
      when Symbol
        Link.new(name: sexp)
      when Array
        sexp.map { |e| link_sexp(e) }
      else
        sexp
      end
    end

    # Returns Base64 image data
    def render_graphviz_png_data(sexp)
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
    :BEGIN => {
      description: "Adds a global initialization hook, always with curly braces.",
      examples: ["BEGIN { do_stuff }"],
      arguments: [:block]
    },
    :CHAR => {
      description: "A one-character string literal, with `?`.",
      lex_examples: ["?a"],
      arguments: [:string, :position]
    },
    :END => {
      description: "Adds a global shutdown hook, always with curly braces",
      examples: ["END { do_stuff }"],
      arguments: [:block]
    },
    :__end__ => {
      description: "Delimits the Ruby script from the following data (`DATA`). Interestingly, the following data is _absent_ from the parsed s-expression.",
      examples: ["a\n__END__\nwacky stuff"],
      lex_examples: ["a\n__END__\nwacky stuff"],
      arguments: [:string, :position]
    },
    :alias => {
      description: "`alias` keyword, whose arguments are always parsed as `:symbol_literal`s",
      examples: ["alias :a :b", "alias a b"],
      arguments: [:new_method, :old_method]
    },
    :alias_error => {},
    :aref => {
      description: "Value lookup with square brackets. (Short for \"array reference\"?)",
      examples: ["a[:b]", "c[0..2]"],
      arguments: [:receiver, :arguments],
    },
    :aref_field => {
      description: "Square bracket access, but when used in the context of assignment.",
      examples: ["[0,1,2][1] = 2"],
      arguments: [:receiver, :arguments]
    },
    :arg_ambiguous => {},
    :arg_paren => {
      description: "Explicit parentheses for arguments",
      examples: ["a(1)"],
      arguments: [:arguments]
    },
    :args_add => {
      description: "The beginning of a list of arguments.",
      examples: ["a(1)", "a(1, b: 2)"],
      arguments: ["??"],
    },
    :args_add_block => {
      description: "An args list, may also contain an `&`-passed block.",
      examples: ["a(&b)", "a(b)", "a(b, &c)"],
      arguments: [:normal_args, :ampersand_block]
    },
    :args_add_star => {
      description: "An arguments list with a splatted array of arguments.",
      examples: ["a(*b)", "a(b, c, *d)"],
      arguments: [:preceding_args, :spatted_arg]
    },
    :args_new => {},
    :array => {},
    :assign => {
      description: "Usage of the assignment operator, =, with a left-hand side (receiving the value) and a right-hand side (the value).",
      examples: ["a = 1", "obj.x = other.y"],
      arguments: [:lhs, :rhs],
    },
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
    :comment => {
      description: "A code comment, preceded with `#`.",
      lex_examples: ["# hi"],
    },
    :const => {
      description: "A literal reference to a constant (variable beginning with a capital letter).",
      examples: ["A = 1", "A.b", "module A; include B; end"],
      arguments: [:name, :position],
    },
    :const_path_field => {},
    :const_path_ref => {},
    :const_ref => {},
    :cvar => {},
    :def => {},
    :defined => {},
    :defs => {},
    :do_block => {},
    :dot2 => {
      description: "Two dots, `..`, for inclusive ranges or flip-flop operator.",
      examples: ["1..10", "if x..y; end"],
      arguments: [:lhs, :rhs],
    },
    :dot3 => {
      description: "Three dots, `...`, use for exclusive ranges.",
      examples: ["'a'...'k'"],
      arguments: [:lhs, :rhs],
    },
    :dyna_symbol => {
      description: "A symbol literal, created from a string.",
      examples: [':"x"', ':"x#{y}"'],
      arguments: [:contents],
    },
    :else => {
      description: "An `else` keyword, used with `if` or `begin`-`rescue`.",
      examples: ["if a; b; else; c; end", "begin; a; rescue; b; else; c; end"],
      arguments: [:statements],
    },
    :elsif => {},
    :embdoc => {},
    :embdoc_beg => {},
    :embdoc_end => {},
    :embexpr_beg => {},
    :embexpr_end => {},
    :embvar => {},
    :ensure => {},
    :excessed_comma => {},
    :fcall => {
      description: "A method call without a receiver, but syntactically known to be a method call, not a local variable reference. (This can be known by the presence of arguments.)",
      examples: ["a(b)", "a { }"],
      arguments: [:method_name, :args],
    },
    :field => {},
    :float => {},
    :for => {},
    :gvar => {},
    :hash => {},
    :heredoc_beg => {},
    :heredoc_dedent => {},
    :heredoc_end => {},
    :ident => {
      description: "A local reference (not a constant) which may be a method call or local variable reference.",
      examples: ["a", "b = 1", "C.d"],
      lex_examples: ["a", "A.a"],
      arguments: [:name, :position],
    },
    :if => {},
    :if_mod => {
      description: "Line-final if.",
      examples: ["a if b"],
      arguments: [:statement, :condition],
    },
    :ifop => {},
    :ignored_nl => {},
    :imaginary => {
      description: "The imaginary part of a complex number",
      examples: ["2+1i"],
      lex_examples: ["2i"],
      arguments: [:string, :position],
    },
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

  # Ensure that the documentation hash is up-to-date with Ripper::EVENTS in this ruby version
  def validate_events(ev_hash)
    all_events = Ripper::EVENTS.dup
    ev_hash.each_key { |k| all_events.delete(k) || raise("Documented key not found in Ripper::EVENTS: #{k.inspect}") }
    if all_events.any?
      raise "Some Ripper::EVENTS not documented: #{all_events.map(&:inspect).join(", ")}"
    end
  end
end
