# Test DECSC and DECRC.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestDecscrc < TestBase
  def test_00_decsc_decrc
    #              (F,B,b,f,s,u,F,r)
    assert_screen [
        5, 3, "\e[41;33mtest\e7\e[2H\e[42;34mgrok\e7\e[m\e[3Hfoo\e82\e81",
        "test1", [ [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0],
                   [3,1,0,0,0,0,0,0] ],
        "grok2", [ [4,2,0,0,0,0,0,0],
                   [4,2,0,0,0,0,0,0],
                   [4,2,0,0,0,0,0,0],
                   [4,2,0,0,0,0,0,0],
                   [4,2,0,0,0,0,0,0] ],
        "foo\0\0",[[7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0],
                   [7,0,0,0,0,0,0,0]]
      ]
  end
end
