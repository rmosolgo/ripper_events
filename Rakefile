file 'index.html' => ['events.rb', 'template.html.erb', 'all_events.rb', 'ripper_graphviz.rb'] do |t|
  require "erb"
  load t.prerequisites[0]
  include Events
  ripper_data = ALL_EVENTS
  validate_events(ripper_data)
  template = File.read(t.prerequisites[1])
  html = ERB.new(template).result(binding)
  File.write(t.name, html)
end

task default: "index.html"
