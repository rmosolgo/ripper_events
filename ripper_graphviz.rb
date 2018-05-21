require "ripper"
require "graphviz"
require "open3"
require "base64"

# A parser which can output pretty Graphviz graphs
class RipperGraphviz < Ripper

  def initialize(*)
    super
    @graph = Graphviz::Graph.new(ordering: "out")
  end

  def to_dot
    @graph.to_dot
  end

  def to_png(filename: nil, base64: false)
    data = nil
    dot = to_dot
    Open3.popen3("dot", "-Tpng") do |stdin, stdout, stderr, thd|
      stdin.puts(dot)
      stdin.close
      # err = stderr.gets(nil)
      # if err
      #   warn(err)
      # end
      data = stdout.gets(nil)
    end
    if base64
      data = Base64.encode64(data)
    end
    if filename
      File.write(filename, data)
    end
    data
  end

  private

  def connect(parent, child, as = nil)
    node = case child
    when Graphviz::Node
      child
    when String, Symbol, Integer, Float, FalseClass, TrueClass
      Graphviz::Node.new(
        rand.to_s,
        @graph,
        label: child.to_s,
      )
    when Array
      new_parent = Graphviz::Node.new(
        rand.to_s,
        @graph,
        label: "[...]",
      )
      child.each_with_index { |c, idx| connect(new_parent, c) }
      new_parent
    when nil
      Graphviz::Node.new(
        rand.to_s,
        @graph,
        label: "nil",
        fontcolor: "#999999",
        color: "#999999",
      )
    else
      raise "Unexpected child: #{child.inspect}"
    end

    edge_opts = {}
    if as
      edge_opts[:label] = as
      edge_opts[:fontsize] = 10.0
    end
    if child.nil?
      edge_opts[:color] = "#999999"
      edge_opts[:fontcolor] = "#999999"
    end
    parent.connect(node, edge_opts)
  end

  defined_handlers = private_instance_methods(false).grep(/\Aon_/) {$'.to_sym}
  (PARSER_EVENTS - defined_handlers).each do |event|
    attrs = ALL_EVENTS[event][:arguments]
    args_code = attrs ? attrs.join(", ") : "*args"
    attr_code = attrs ? attrs.map { |a| "connect(node, #{a}, :#{a})" }.join("\n")  : "args.each { |a| connect(node, a) }"
    module_eval(<<-RUBY, __FILE__, __LINE__ + 1)
      def on_#{event}(#{args_code})
        node = Graphviz::Node.new(
          "#{event}.\#{rand.to_s}",
          @graph,
          label: "#{event}",
        )
        #{attr_code}
        node
      end
    RUBY
  end

  SCANNER_EVENTS.each do |event|
    module_eval(<<-End, __FILE__, __LINE__ + 1)
      def on_#{event}(tok)
        "@#{event} `\#{tok}` (\#{lineno()}, \#{column()})"
      end
    End
  end
end
