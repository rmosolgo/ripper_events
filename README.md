# Ripper Events

A project for discovering and documenting the events in Ruby's [Ripper](http://ruby-doc.org/stdlib-2.5.0/libdoc/ripper/rdoc/Ripper.html) parser.

Visible on GitHub pages: https://rmosolgo.github.io/ripper_events/

## Development

- Install deps with:
  - `bundle install`
  - `brew install graphviz` (or install Graphviz another way)
- Update the docs in `events.rb`
- Update the HTML template in `template.html.erb`
- Rebuild the HTML with `rake`
- View the rendered page with `open index.html`
- Push `gh-pages` to update the website
