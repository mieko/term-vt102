# Make sure the VT102 module can set its size OK.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestSetsize < TestBase
  def test_sizes
    assert_equal [80, 24], Term::VT102.new.size
    assert_equal [ 1,  1], Term::VT102.new(cols:  1, rows: 1).size
    assert_equal [80, 24], Term::VT102.new(cols: 80, rows: 24).size
    assert_equal [80, 24], Term::VT102.new(cols: -1000, rows: -1000).size
  end
end
