# Make sure the VT102 module can handle cursor positioning.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestCursor < TestBase
  def test_originals
    assert_screens [
      [ 20, 5, "\e[2;4Hline 1\r\nline 2",		# CUP - ESC [ y ; * H
        "\0" * 20,
        ("\0" * 3) + "line 1" + ("\0" * 11),
        "line 2" + ("\0" * 14),
      ],
      [ 20, 5, "\e[3Hline 1\nline 2",		# CUP - ESC [ y H
        "\0" * 20,
        "\0" * 20,
        "line 1" + ("\0" * 14),
        ("\0" * 6) + "line 2" + ("\0" * 8),
      ],
      [ 20, 5, "\e[2Hline 1\nline 2\e[1Hline 3",	# CUP, CUP, LF
        "line 3" + ("\0" * 14),
        "line 1" + ("\0" * 14),
        ("\0" * 6) + "line 2" + ("\0" * 8),
      ],
      [ 10, 4, "\e[2;6Hline 1\r\nline 2\eM\eMtop",	# CUP, CR, LF, RI (ESC M)
        ("\0" * 6) + "top" + "\0",
        ("\0" * 5) + "line ",
        "line 2" + ("\0" * 4),
        ("\0" * 10),
      ],
      [ 20, 8, "\e[4;10Hmiddle\e[Htop line\eD" +	# IND, NEL, CUU, CUF
               "row 2\eE\rrow 3\e[A\e[8Cmark",
        "top line" + ("\0" * 12),
        ("\0" * 8) + "row 2mark" + ("\0" * 3),
        "row 3" + ("\0" * 15),
        ("\0" * 9) + "middle" + ("\0" * 5),
      ],
      [ 20, 4, "row 1\e[Brow 2\e[7Da\e[2Erow 4",	# CUD, CUB, CNL
        "row 1" + ("\0" * 15),
        ("\0" * 3) + "a\0row 2" + ("\0" * 10),
        "\0" * 20,
        "row 4" + ("\0" * 15),
      ],
      [ 20, 4, "\e[3;4Hrow 3\e[2Frow 1" +		# CPL, CHA, HPR, VPA
               "\e[9Gmiddle 1\e[2aa\e[2db",
        "row 1" + ("\0" * 3) + "middle 1" + ("\0" * 2) + "a\0",
        ("\0" * 19) + "b",
        ("\0" * 3) + "row 3" + ("\0" * 12),
      ],
      [ 20, 3, "\e[2erow 3\e[2;4frow 2\e[15\`mark",	# VPR, HVP, HPA
        ("\0" * 20),
        ("\0" * 3) + "row 2" + ("\0" * 6) + "mark" + ("\0" * 2),
        "row 3" + ("\0" * 15),
      ],
      [ 10, 5, "\e[999;999HR\e[GL\e[Hl\e[999Gr",
        "l" + ("\0" * 8) + "r",
        ("\0" * 10),
        ("\0" * 10),
        ("\0" * 10),
        "L" + ("\0" * 8) + "R",
      ],
      [ 20, 8, "Trap\e[CLog\e[CDisplay",  # reported by Paul Stoddard
        "Trap\0Log\0Display" + ("\0" * 4),
        ("\0" * 20),
      ],
    ]
  end
end
