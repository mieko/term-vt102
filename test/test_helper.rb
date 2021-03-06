$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/autorun'
require 'term/vt102'

class TestBase < Minitest::Test
  # These aren't actually order dependent, but it's nice to see them in
  # the same order as the Perl original, for comparison's sake.
  i_suck_and_my_tests_are_order_dependent!

  # These were public in the perl module.  Let's hack access.
  def attr_pack(vt, *args)
    vt.send(:attr_pack, *args)
  end

  def attr_unpack(vt, *args)
    vt.send(:attr_unpack, *args)
  end

  def show_text(text)
    return '' if text.nil?

    text.gsub!(/[^\040-\176]/) do |one|
      sprintf('\\%o', one.ord)
    end

    text
  end

  def show_attr(vt, attr)
    fg, bg, bo, fa, st, ul, bl, rv = attr_unpack(vt, attr)
    str = "#{fg}-#{bg}"

    str += 'b' if bo != 0
    str += 'f' if fa != 0
    str += 's' if st != 0
    str += 'u' if ul != 0
    str += 'F' if bl != 0
    str += 'r' if rv != 0

    return str + '-' + sprintf('%04X', attr)
  end

  def assert_screens(screens)
    screens.each do |screen|
      assert_screen(screen)
    end
  end

  def assert_screen(screen)
    settings = nil

    cols, rows, text, *output = screen
    settings = nil
    if cols.is_a?(Enumerable)
      settings, cols, rows, text, *output = screen
    end

    vt = Term::VT102.new(cols: cols, rows: rows)
    assert_equal [cols, rows], vt.size

    if settings
      settings.each do |k, v|
        vt.send("#{k}=", v)
      end
    end

    vt.process(text)

    row = 0

    alineref = nil
    while output.size - 1 > 0
      line = output.shift
      if output.first.is_a?(Array)
        alineref = output.shift
        aline = []
        alineref.each do |l|
          aline += [attr_pack(vt, *l)]
        end
      else
        alineref = nil
      end

      row += 1
      assert_equal line, vt.row_text(row), "row #{row} incorrect"

      next if alineref.nil?

      galine = vt.row_attr(row)
      (1...cols).each do |col|
        expected = aline[col]
        actual = galine[col]

        assert_equal expected, actual,
                     "row #{row}; attributes #{show_attr(vt, expected)} vs " +
                     "#{show_attr(vt, actual)}"
      end
    end
  end
end
