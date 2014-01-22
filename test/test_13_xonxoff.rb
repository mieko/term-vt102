# Test XOFF and XON.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestXonxoff < TestBase
  def test_00_xon_xoff
    #                 (F,B,b,f,s,u,F,r)
    assert_screens [
      [ { 'IGNOREXOFF' => 0 },
          6, 2, "foo\023bar\e[1m\021baz",
          "foobaz", [ [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0] ],
          "\0\0\0\0\0\0",
                   [ [7,0,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0],
                     [7,0,0,0,0,0,0,0] ],
        ],
        [ { 'IGNOREXOFF' => 1 },
          9, 1, "foo\023bar\e[1m\021baz",
          "foobarbaz",
                    [ [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,0,0,0,0,0,0],
                      [7,0,1,0,0,0,0,0],
                      [7,0,1,0,0,0,0,0],
                      [7,0,1,0,0,0,0,0] ],
        ]
    ]
  end
end

