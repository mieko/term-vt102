# Term::VT102

Term::VT102 provides emulation of a VT102 terminal, in Ruby.  It's a great way
to automate interactions with remote systems, particularly ones that only
provide interactive/curses style interfaces.  It can tell you what's on the
screen at any time, and notify you of changes.

A lot of terrible legacy applications fall into this category.

This gem is a port of Andrew Wood's Perl module, Term::VT102.  Permission has
been granted to release this derived work under the MIT license.

Term::VT102 aims to be fairly literal port of the Perl module, and higher-level
features will most likely show up in other gems instead of being integrated
here.

## Installation

Add this line to your application's Gemfile:

    gem 'term-vt102'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install term-vt102

## Usage

```ruby

require 'term/vt102'

vt = Term::VT102.new(cols: 80, rows: 25)

# Await patiently at your editor for me to write documentation, or check out
# the tests.

```

## Contributing

1. Fork it ( http://github.com/mieko/term-vt102/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
