# Make sure the VT102 module can handle line and character insertion and
# deletion, and line/screen clearing.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'test_helper'
require 'term/vt102'

class TestInsdel < TestBase
  def fill
    "0123456789\r\n" +
    "1234567890\r\n" +
    "2345678901\r\n" +
    "3456789012\e[H"
  end

  def test_00_nothing
    assert_screen [
      10, 4, fill + "",				# 1: nothing
      "0123456789",
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_01_dch_1
    assert_screen [
      10, 4, fill + "\e[P",			# 2: DCH 1
      "123456789\0",
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_02_dch_2
    assert_screen [
      10, 4, fill + "\e[2;8H\e[2P",		# 3: DCH 2
      "0123456789",
      "12345670\0\0",
      "2345678901",
      "3456789012"]
  end

  def test_03_dch_9
    assert_screen [
      10, 4, fill + "\e[3;7H\e[9P",		# 4: DCH 9
      "0123456789",
      "1234567890",
      "234567\0\0\0\0",
      "3456789012"]
  end

  def test_04_ech_1
    assert_screen [
      10, 4, fill + "\e[X",			# 5: ECH 1
      "\0" + "123456789",
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_05_ech_2
    assert_screen [
      10, 4, fill + "\e[2;8H\e[2X",		# 6: ECH 2
      "0123456789",
      "1234567\0\0" + "0",
      "2345678901",
      "3456789012"]
  end

  def test_06_ech_9
    assert_screen [
      10, 4, fill + "\e[3;7H\e[9X",		# 7: ECH 9
      "0123456789",
      "1234567890",
      "234567\0\0\0\0",
      "3456789012"]
  end


  def test_07_ich_1
    assert_screen [
      10, 4, fill + "\e[@",			# 8: ICH 1
      "\0" + "012345678",
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_08_ich_2
    assert_screen [
      10, 4, fill + "\e[2;8H\e[2@",		# 9: ICH 2
      "0123456789",
      "1234567\0\0" + "8",
      "2345678901",
      "3456789012"]
  end

  def test_09_ich_9
    assert_screen [
      10, 4, fill + "\e[3;7H\e[9@",		# 10: ICH 9
      "0123456789",
      "1234567890",
      "234567\0\0\0\0",
      "3456789012"]
  end

  def test_10_ed_0
    assert_screen [
      10, 4, fill + "\e[2;4H\e[J",		# 11: ED 0
      "0123456789",
      "123" + ("\0" * 7),
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_11_ed_1
    assert_screen [
      10, 4, fill + "\e[2;4H\e[1J",		# 12: ED 1
      ("\0" * 10),
      ("\0" * 4) + "567890",
      "2345678901",
      "3456789012"]
  end

  def test_12_ed_2
    assert_screen [
      10, 4, fill + "\e[2;4H\e[2J",		# 13: ED 2
      ("\0" * 10),
      ("\0" * 10),
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_13_el_0
    assert_screen [
      10, 4, fill + "\e[2;4H\e[K",		# 14: EL 0
      "0123456789",
      "123" + ("\0" * 7),
      "2345678901",
      "3456789012"]
  end

  def test_14_el_1
    assert_screen [
      10, 4, fill + "\e[2;4H\e[1K",		# 15: EL 1
      "0123456789",
      ("\0" * 4) + "567890",
      "2345678901",
      "3456789012"]
  end

  def test_15_el_2
    assert_screen [
      10, 4, fill + "\e[2;4H\e[2K",		# 16: EL 2
      "0123456789",
      ("\0" * 10),
      "2345678901",
      "3456789012"]
  end

  def test_16_il_1
    assert_screen [
      10, 4, fill + "\e[2;4H\e[LAbC",		# 17: IL 1
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      "1234567890",
      "2345678901"]
  end

  def test_17_il_2
    assert_screen [
      10, 4, fill + "\e[2;4H\e[2LAbC",		# 18: IL 2
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      "1234567890"]
  end

  def test_18_il_3
    assert_screen [
      10, 4, fill + "\e[2;4H\e[9LAbC",		# 19: IL 3
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_19_il_4
    assert_screen [
      10, 4, fill + "\e[1;1H\e[2LAbC",		# 20: IL 4
      "AbC" + ("\0" * 7),
      ("\0" * 10),
      "0123456789",
      "1234567890"]
  end

  def test_20_dl_1
    assert_screen [
      10, 4, fill + "\e[2;4H\e[MAbC",		# 21: DL 1
      "0123456789",
      "234AbC8901",
      "3456789012",
      ("\0" * 10)]
  end

  def test_21_dl_2
    assert_screen [
      10, 4, fill + "\e[2;4H\e[2MAbC",		# 22: DL 2
      "0123456789",
      "345AbC9012",
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_22_el_3
    assert_screen [
      10, 4, fill + "\e[2;4H\e[9MAbC",		# 23: DL 3
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_23_dl_4
    assert_screen [
      10, 4, fill + "\e[1;1H\e[2MAbC",		# 24: DL 4
      "AbC5678901",
      "3456789012",
      ("\0" * 10),
      ("\0" * 10)]
  end

  def test_24_decstbm_il_1
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[LAbC",	# 25: DECSTBM IL 1
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      "1234567890",
      "3456789012"]
  end

  def test_25_decstbm_il_2
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[2LAbC",	# 26: DECSTBM IL 2
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      "3456789012"]
  end

  def test_26_decstbm_il_3
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[9LAbC",	# 27: DECSTBM IL 3
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      "3456789012"]
  end

  def test_27_decstbm_il_4
    assert_screen [
      10, 4, fill + "\e[2;3r\e[1;1H\e[2LAbC",	# 28: DECSTBM IL 4
      "AbC" + ("\0" * 7),
      "1234567890",
      "2345678901",
      "3456789012"]
  end

  def test_28_decstbm_dl_1
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[MAbC",	# 29: DECSTBM DL 1
      "0123456789",
      "234AbC8901",
      ("\0" * 10),
      "3456789012"]
  end

  def test_29_decstbm_dl_2
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[2MAbC",	# 30: DECSTBM DL 2
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      "3456789012"]
  end

  def test_30_decstbm_dl_3
    assert_screen [
      10, 4, fill + "\e[2;3r\e[2;4H\e[9MAbC",	# 31: DECSTBM DL 3
      "0123456789",
      ("\0" * 3) + "AbC" + ("\0" * 4),
      ("\0" * 10),
      "3456789012"]
  end

  def test_32_decstbm_dl_4
    assert_screen [
      10, 4, fill + "\e[2;3r\e[1;1H\e[2MAbC",	# 32: DECSTBM DL 4
      "AbC" + ("\0" * 7),
      "1234567890",
      "2345678901",
      "3456789012"]
  end

end
