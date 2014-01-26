# Make sure the VT102 module can process basic text OK.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestText < TestBase
  def test_originals
    assert_screen [
        10, 5, "line 1\r\n  line 2\r\n  line 3\r\nline 4",
        "line 1" + ("\0" * 4),
        "  line 2" + ("\0" * 2),
        "  line 3" + ("\0" * 2),
        "line 4" + ("\0" * 4),
      ]

    assert_screen [
        80, 25, " line 1 \n    line 2\n    line 3\n line 4 ",
        " line 1 " + ("\0" * 72),
        ("\0" * 8) + "    line 2" + ("\0" * 62),
        ("\0" * 18) + "    line 3" + ("\0" * 52),
        ("\0" * 28) + " line 4 " + ("\0" * 44),
      ]

    assert_screen [
      40, 5, "line 1\ttab 1\r\n  line 2\ttab 2\ttab 3\r\n  line 3\r\nline 4",
        "line 1\0\0tab 1" + ("\0" * 27),
        "  line 2\0\0\0\0\0\0\0\0tab 2\0\0\0tab 3" + ("\0" * 11),
        "  line 3" + ("\0" * 32),
        "line 4" + ("\0" * 34),
      ]
  end
end