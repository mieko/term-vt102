# Make sure the VT102 module loads OK and can return its version number.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestLoad < TestBase
  def test_that_it_has_a_version_number
    refute_nil ::Term::VT102::VERSION
  end
end
