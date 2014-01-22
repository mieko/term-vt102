# Make sure the VT102 module's option settings work.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestOptions < TestBase
  def test_00_options
    assert_screens [
      [ { 'LFTOCRLF' => 1 }, 10, 5, "line 1\n  line 2\n  line 3\nline 4",
        "line 1" + ("\0" * 4),
        "  line 2" + ("\0" * 2),
        "  line 3" + ("\0" * 2),
        "line 4" + ("\0" * 4),
      ],
      [ { 'LINEWRAP' => 1 }, 10, 5, "abcdefghijklmnopqrstuvwxyz",
        "abcdefghij",
        "klmnopqrst",
        "uvwxyz" + ("\0" * 4),
      ],
    ]
  end
end
