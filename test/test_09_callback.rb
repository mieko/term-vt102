# Make sure the VT102 module's callbacks.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestCallback < TestBase
	def setup
		@vt = Term::VT102.new(cols: 80, rows: 25)
		@testarg1 = @testarg2 = @testpriv = 0
	end

	def testcallback
		-> (tty, callname, arg1, arg2, priv) do
			@testarg1, @testarg2, @testpriv = arg1, arg2, priv
		end
	end

	def test_00_rowchange_runs
		@vt.callback_call('ROWCHANGE', 0, 0)
	end

	def test_01_rowchange_sets_private_data
		@vt.callback_set('ROWCHANGE', testcallback, 123)
		@vt.callback_call('ROWCHANGE', 0, 0)
		assert_equal 123, @testpriv
	end

	def test_02_string_callback_reports_esc
		@vt.callback_set('STRING', testcallback, 2)
		@vt.process("\033_Test String\033\\test")

		assert_equal 'APC', @testarg1
		assert_equal 'Test String', @testarg2
		assert_equal 2, @testpriv
	end

	def test_03_xicon
		@vt.callback_set('XICONNAME', testcallback, 3)
		@vt.process("\033]1;Test Icon Name\033\\test")

		assert_equal 'Test Icon Name', @testarg1
		assert_equal 3, @testpriv
	end

	def test_04_xwintitle
		@vt.callback_set('XWINTITLE', testcallback, 4)
		@vt.process("\033]2;Test Title\033\\test")

		assert_equal 'Test Title', @testarg1
		assert_equal 4, @testpriv
	end
end
