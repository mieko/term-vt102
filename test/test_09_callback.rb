# Make sure the VT102 module's callbacks.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestCallback < TestBase
	def setup
		@vt = Term::VT102.new(cols: 80, rows: 25)
		@testcb = nil
		@testargs = []
	end

	def testcallback
		-> (cb, *args) do
			@testcb, @testargs = cb, args
		end
	end

	def test_00_rowchange_runs
		@vt.callback_call(:rowchange, 0, 0)
	end

	def test_01_rowchange_sets_private_data
		@vt.callback_set(:rowchange, &testcallback)
		@vt.callback_call(:rowchange, 0, 0)
	end

	def test_02_string_callback_reports_esc
		@vt.callback_set(:string, &testcallback)
		@vt.process("\033_Test String\033\\test")

		assert_equal :apc, @testargs[0]
		assert_equal 'Test String', @testargs[1]
	end

	def test_03_xicon
		@vt.callback_set(:xiconname, &testcallback)
		@vt.process("\033]1;Test Icon Name\033\\test")

		assert_equal 'Test Icon Name', @testargs[0]
	end

	def test_04_xwintitle
		@vt.callback_set(:xwintitle, &testcallback)
		@vt.process("\033]2;Test Title\033\\test")

		assert_equal 'Test Title', @testargs[0]
	end
end
