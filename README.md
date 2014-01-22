# Term::VT102

`Term::VT102` provides emulation of a VT102 terminal.  It's a great way to
automate interactions with remote systems, particularly ones that only provide
interactive/curses style interfaces.  It can tell you what's on the screen at
any time, and notify you of changes.

A lot of terrible legacy applications fall into this category.

This gem is a port of Andrew Wood's Perl module, `Term::VT102`, available
at http://www.ivarch.com/programs/termvt102.shtml

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

vt.on(:rowchange) do |row, x, y|
  # FIXME, real example.  See the tests.
end

```

## Contributing

1. Fork it ( http://github.com/mieko/term-vt102/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
