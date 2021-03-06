# Test DECALN.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestDecaln < TestBase
  def test_00_decaln
    #              (F,B,b,f,s,u,F,r)
    assert_screen [
        5, 3, "b\e[41;33mlah\nblah\r\nblah\e#8test",
        "testE", [ [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0] ],
        "EEEEE", [ [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0] ],
        "EEEEE", [ [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0] ],
      ]
  end
end