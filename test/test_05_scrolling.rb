# Make sure the VT102 module can handle scrolling up and down.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestScrolling < TestBase
  def fill
    "0123456789\r\n" +
    "1234567890\r\n" +
    "2345678901\r\n" +
    "3456789012\e[H"
  end

  def fill2
    "0123456789\r\n" +
    "1234567890\r\n" +
    "2345678901\r\n" +
    "3456789012\e[2;3r\e[2H"
  end

  def test_00_nothing
    assert_screen [
        10, 4, fill + "",				# 1: nothing
        "0123456789",
        "1234567890",
        "2345678901",
        "3456789012" ]
  end

  def test_01_lf
    assert_screen [
        10, 4, fill + "\e[4H\ntest",		# 2: LF
        "1234567890",
        "2345678901",
        "3456789012",
        "test" + ("\0" * 6)]
  end

  def test_02_ri
    assert_screen [
      10, 4, fill + "\eMtest",			# 3: RI
        "test" + ("\0" * 6),
        "0123456789",
        "1234567890",
        "2345678901"]
  end

  def test_03_ind
    assert_screen [
      10, 4, fill + "\e[4H\eDtest",		# 4: IND
      "1234567890",
      "2345678901",
      "3456789012",
      "test" + ("\0" * 6)]
  end

  def test_04_nel
    assert_screen [
      10, 4, fill + "\e[4H\eEtest",		# 5: NEL
      "1234567890",
      "2345678901",
      "3456789012",
      "test" + ("\0" * 6)]
  end

  def test_05_cuu
    assert_screen [
      10, 4, fill + "\e[2Atest",			# 6: CUU
      "test" + ("\0" * 6),
      "\0" * 10,
      "0123456789",
      "1234567890"]
  end

  def test_06_cuu2
    assert_screen [
      10, 4, fill + "\e[8Atest",			# 7: CUU
      "test" + ("\0" * 6),
      "\0" * 10,
      "\0" * 10,
      "\0" * 10]
  end

  def test_07_cud
    assert_screen [
      10, 4, fill + "\e[4H\e[2Btest",		# 8: CUD
      "2345678901",
      "3456789012",
      "\0" * 10,
      "test" + ("\0" * 6)]
  end

  def test_08_cnl
    assert_screen [
      10, 4, fill + "\e[4H\e[2Etest",		# 9: CNL
      "2345678901",
      "3456789012",
      "\0" * 10,
      "test" + ("\0" * 6)]
  end

  def test_09_cnl2
    assert_screen [
      10, 4, fill + "\e[4H\e[9Etest",		# 10: CNL
      "\0" * 10,
      "\0" * 10,
      "\0" * 10,
      "test" + ("\0" * 6)]
  end

  def test_10_cpl
    assert_screen [
      10, 4, fill + "\e[2Ftest",			# 11: CPL
      "test" + ("\0" * 6),
      "\0" * 10,
      "0123456789",
      "1234567890"]
  end

  def test_11_nothing_decstbm
    assert_screen [
      10, 4, fill2 + "",				# 12: nothing (with DECSTBM)
      "0123456789",
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_12_decstbm_cnl
    assert_screen [
      10, 4, fill2 + "\e[3H\e[Etest",		# 13: DECSTBM CNL
      "0123456789",
      "2345678901",
      "test" + ("\0" * 6),
      "3456789012"]
  end

  def test_13_decstbm_cpl
    assert_screen [
      10, 4, fill2 + "\e[Ftest",			# 14: DECSTBM CPL
      "0123456789",
      "test" + ("\0" * 6),
      "1234567890",
      "3456789012"]
  end

  def test_14_decstbm_cnl2
    assert_screen [
      10, 4, fill2 + "\e[3H\e[2Etest",		# 15: DECSTBM CNL 2
      "0123456789",
      "\0" * 10,
      "test" + ("\0" * 6),
      "3456789012"]
  end

  def test_15_decstbm_cpl_2
    assert_screen [
      10, 4, fill2 + "\e[2Ftest",		# 16: DECSTBM CPL 2
      "0123456789",
      "test" + ("\0" * 6),
      "\0" * 10,
      "3456789012"]
  end

  def test_16_decstbm_cnl_4
    assert_screen [
      10, 4, fill2 + "\e[3H\e[4Etest",		# 17: DECSTBM CNL 4
      "0123456789",
      "\0" * 10,
      "test" + ("\0" * 6),
      "3456789012"]
  end

  def test_17_decstbm_cpl_4
    assert_screen [
      10, 4, fill2 + "\e[4Ftest",		# 18: DECSTBM CPL 4
      "0123456789",
      "test" + ("\0" * 6),
      "\0" * 10,
      "3456789012"]
  end
end
