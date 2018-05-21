require "ripper"
require "graphviz"
require "open3"
require "base64"
require "pp"
require "kramdown"
require_relative "./all_events"
require_relative "./ripper_graphviz"
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
        parser = RipperGraphviz.new(code)
        parser.parse
        image_data = parser.to_png(base64: true)
        @rendered_image = %|<img src="data:image/png;base64,#{image_data}"/>|
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



  # Ensure that the documentation hash is up-to-date with Ripper::EVENTS in this ruby version
  def validate_events(ev_hash)
    all_events = Ripper::EVENTS.dup
    ev_hash.each_key { |k| all_events.delete(k) || raise("Documented key not found in Ripper::EVENTS: #{k.inspect}") }
    if all_events.any?
      raise "Some Ripper::EVENTS not documented: #{all_events.map(&:inspect).join(", ")}"
    end
  end
end
