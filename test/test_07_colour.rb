# Make sure the VT102 module can handle ANSI colour, underline, bold, etc.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestColour < TestBase
  def test_original
    #                (F,B,b,f,s,u,F,r)
    assert_screen [
        7, 4, "\e[m0\e[1m1\e[2m2\e[4m3\e[5m4\e[7m5\e[m6\r\n",
        "0123456", [ [7,0,0,0,0,0,0,0],
                     [7,0,1,0,0,0,0,0],
                     [7,0,0,1,0,0,0,0],
                     [7,0,0,1,0,1,0,0],
                     [7,0,0,1,0,1,1,0],
                     [7,0,0,1,0,1,1,1],
                     [7,0,0,0,0,0,0,0] ]
      ]

    assert_screen [
        7, 4, "\e[41;35m0\e[1m1\e[2m2\e[4m3\e[5m4\e[7m5\e[m6\r\n",
        "0123456", [ [5,1,0,0,0,0,0,0],
                     [5,1,1,0,0,0,0,0],
                     [5,1,0,1,0,0,0,0],
                     [5,1,0,1,0,1,0,0],
                     [5,1,0,1,0,1,1,0],
                     [5,1,0,1,0,1,1,1],
                     [7,0,0,0,0,0,0,0] ]
      ]

    assert_screen [
        8, 4, "\e[33;42m0\e[1m1\e[21m2\e[2m3\e[22m4\e[38m5\e[39m6\e[49m7\r\n",
        "01234567",[ [3,2,0,0,0,0,0,0],
                     [3,2,1,0,0,0,0,0],
                     [3,2,0,0,0,0,0,0],
                     [3,2,0,1,0,0,0,0],
                     [3,2,0,0,0,0,0,0],
                     [7,2,0,0,0,1,0,0],
                     [7,2,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0] ],
      ]
  end
end
