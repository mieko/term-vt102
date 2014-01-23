# Term::VT102 - module for VT102 emulation in Ruby
#
# Ported from Andrew Wood's Perl module, 'Term::VT102'.
#
# Copyright (C) Andrew Wood
# Copyright (C) Mike Owens <mike@filespanker.com>
# NO WARRANTY - see LICENSE.txt
#

require 'term/vt102/version'

module Term
  class VT102
    # Return the packed version of a set of attributes fg, bg, bo, fa, st, ul,
    # bl, rv.
    #
    def self.attr_pack(fg, bg, bo, fa, st, ul, bl, rv)
      num = (fg & 7)        |
            ((bg & 7) << 4) |
            (bo << 8)       |
            (fa << 9)       |
            (st << 10)      |
            (ul << 11)      |
            (bl << 12)      |
            (rv << 13)
      [num].pack('S')
    end

    def attr_pack(*args)
      self.class.attr_pack(*args)
    end

    # Return the unpacked version of a packed attribute.
    #
    def attr_unpack(data)
      num = data.unpack('S').first

      fg = num & 7
      bg = (num >> 4) & 7
      bo = (num >> 8) & 1
      fa = (num >> 9) & 1
      st = (num >> 10) & 1
      ul = (num >> 11) & 1
      bl = (num >> 12) & 1
      rv = (num >> 13) & 1

      [fg, bg, bo, fa, st, ul, bl, rv]
    end

    DEFAULT_ATTR = [7, 0, 0, 0, 0, 0, 0, 0].freeze
    DEFAULT_ATTR_PACKED = attr_pack(*DEFAULT_ATTR).freeze

    # Constructor function.
    #
    def initialize(cols: 80, rows: 24)
      # control characters
      @_ctlseq = {
        "\000" => 'NUL',          # ignored
        "\005" => 'ENQ',          # trigger answerback message
        "\007" => 'BEL',          # beep
        "\010" => 'BS',           # backspace one column
        "\011" => 'HT',           # horizontal tab to next tab stop
        "\012" => 'LF',           # line feed
        "\013" => 'VT',           # line feed
        "\014" => 'FF',           # line feed
        "\015" => 'CR',           # carriage return
        "\016" => 'SO',           # activate G1 character set & newline
        "\017" => 'SI',           # activate G0 character set
        "\021" => 'XON',          # resume transmission
        "\023" => 'XOFF',         # stop transmission, ignore characters
        "\030" => 'CAN',          # interrupt escape sequence
        "\032" => 'SUB',          # interrupt escape sequence
        "\033" => 'ESC',          # start escape sequence
        "\177" => 'DEL',          # ignored
        "\233" => 'CSI'           # equivalent to ESC [
      }

      # escape sequences
      @_escseq = {
       'c'  => 'RIS',             # reset
       'D'  => 'IND',             # line feed
       'E'  => 'NEL',             # newline
       'H'  => 'HTS',             # set tab stop at current column
       'M'  => 'RI',              # reverse line feed
       'Z'  => 'DECID',           # DEC private ID; return ESC [ ? 6 c (VT102)
       '7'  => 'DECSC',           # save state (position, charset, attributes)
       '8'  => 'DECRC',           # restore most recently saved state
       '['  => 'CSI',             # control sequence introducer
       '[[' => 'IGN',             # ignored control sequence
       '%@' => 'CSDFL',           # select default charset (ISO646/8859-1)
       '%G' => 'CSUTF8',          # select UTF-8
       '%8' => 'CSUTF8',          # select UTF-8 (obsolete)
       '#8' => 'DECALN',          # DEC alignment test - fill screen with E's
       '(8' => 'G0DFL',           # G0 charset = default mapping (ISO8859-1)
       '(0' => 'G0GFX',           # G0 charset = VT100 graphics mapping
       '(U' => 'G0ROM',           # G0 charset = null mapping (straight to ROM)
       '(K' => 'G0USR',           # G0 charset = user defined mapping
       '(B' => 'G0TXT',           # G0 charset = ASCII mapping
       ')8' => 'G1DFL',           # G1 charset = default mapping (ISO8859-1)
       ')0' => 'G1GFX',           # G1 charset = VT100 graphics mapping
       ')U' => 'G1ROM',           # G1 charset = null mapping (straight to ROM)
       ')K' => 'G1USR',           # G1 charset = user defined mapping
       ')B' => 'G1TXT',           # G1 charset = ASCII mapping
       '*8' => 'G2DFL',           # G2 charset = default mapping (ISO8859-1)
       '*0' => 'G2GFX',           # G2 charset = VT100 graphics mapping
       '*U' => 'G2ROM',           # G2 charset = null mapping (straight to ROM)
       '*K' => 'G2USR',           # G2 charset = user defined mapping
       '+8' => 'G3DFL',           # G3 charset = default mapping (ISO8859-1)
       '+0' => 'G3GFX',           # G3 charset = VT100 graphics mapping
       '+U' => 'G3ROM',           # G3 charset = null mapping (straight to ROM)
       '+K' => 'G3USR',           # G3 charset = user defined mapping
       '>'  => 'DECPNM',          # set numeric keypad mode
       '='  => 'DECPAM',          # set application keypad mode
       'N'  => 'SS2',             # select G2 charset for next char only
       'O'  => 'SS3',             # select G3 charset for next char only
       'P'  => 'DCS',             # device control string (ended by ST)
       'X'  => 'SOS',             # start of string
       '^'  => 'PM',              # privacy message (ended by ST)
       '_'  => 'APC',             # application program command (ended by ST)
       "\\" => 'ST',              # string terminator
       'n'  => 'LS2',             # invoke G2 charset
       'o'  => 'LS3',             # invoke G3 charset
       '|'  => 'LS3R',            # invoke G3 charset as GR
       '}'  => 'LS2R',            # invoke G2 charset as GR
       '~'  => 'LS1R',            # invoke G1 charset as GR
       ']'  => 'OSC',             # operating system command
       'g'  => 'BEL',             # alternate BEL
      }

      # ECMA-48 CSI sequences
      @_csiseq = {
        '[' => 'IGN',             # ignored control sequence
        '@' => 'ICH',             # insert blank characters
        'A' => 'CUU',             # move cursor up
        'B' => 'CUD',             # move cursor down
        'C' => 'CUF',             # move cursor right
        'D' => 'CUB',             # move cursor left
        'E' => 'CNL',             # move cursor down and to column 1
        'F' => 'CPL',             # move cursor up and to column 1
        'G' => 'CHA',             # move cursor to column in current row
        'H' => 'CUP',             # move cursor to row, column
        'J' => 'ED',              # erase display
        'K' => 'EL',              # erase line
        'L' => 'IL',              # insert blank lines
        'M' => 'DL',              # delete lines
        'P' => 'DCH',             # delete characters on current line
        'X' => 'ECH',             # erase characters on current line
        'a' => 'HPR',             # move cursor right
        'c' => 'DA',              # return ESC [ ? 6 c (VT102)
        'd' => 'VPA',             # move to row (current column)
        'e' => 'VPR',             # move cursor down
        'f' => 'HVP',             # move cursor to row, column
        'g' => 'TBC',             # clear tab stop (CSI 3 g = clear all stops)
        'h' => 'SM',              # set mode
        'l' => 'RM',              # reset mode
        'm' => 'SGR',             # set graphic rendition
        'n' => 'DSR',             # device status report
        'q' => 'DECLL',           # set keyboard LEDs
        'r' => 'DECSTBM',         # set scrolling region to (top, bottom) rows
        's' => 'CUPSV',           # save cursor position
        'u' => 'CUPRS',           # restore cursor position
        '`' => 'HPA'              # move cursor to column in current row
      }

      # ANSI/DEC specified modes for SM/RM
      @_modeseq = {
                               # ANSI Specified Modes
        '0'   => 'IGN',           # Error (Ignored)
        '1'   => 'GATM',          # guarded-area transfer mode (ignored)
        '2'   => 'KAM',           # keyboard action mode (always reset)
        '3'   => 'CRM',           # control representation mode (always reset)
        '4'   => 'IRM',           # insertion/replacement mode (always reset)
        '5'   => 'SRTM',          # status-reporting transfer mode
        '6'   => 'ERM',           # erasure mode (always set)
        '7'   => 'VEM',           # vertical editing mode (ignored)
        '10'  => 'HEM',           # horizontal editing mode
        '11'  => 'PUM',           # positioning unit mode
        '12'  => 'SRM',           # send/receive mode (echo on/off)
        '13'  => 'FEAM',          # format effector action mode
        '14'  => 'FETM',          # format effector transfer mode
        '15'  => 'MATM',          # multiple area transfer mode
        '16'  => 'TTM',           # transfer termination mode
        '17'  => 'SATM',          # selected area transfer mode
        '18'  => 'TSM',           # tabulation stop mode
        '19'  => 'EBM',           # editing boundary mode
        '20'  => 'LNM',           # Line Feed / New Line Mode
                              # DEC Private Modes
        '?0'  => 'IGN',           # Error (Ignored)
        '?1'  => 'DECCKM',        # Cursorkeys application (set); Cursorkeys normal (reset)
        '?2'  => 'DECANM',        # ANSI (set); VT52 (reset)
        '?3'  => 'DECCOLM',       # 132 columns (set); 80 columns (reset)
        '?4'  => 'DECSCLM',       # Jump scroll (set); Smooth scroll (reset)
        '?5'  => 'DECSCNM',       # Reverse screen (set); Normal screen (reset)
        '?6'  => 'DECOM',         # Sets relative coordinates (set); Sets absolute coordinates (reset)
        '?7'  => 'DECAWM',        # Auto Wrap
        '?8'  => 'DECARM',        # Auto Repeat
        '?9'  => 'DECINLM',       # Interlace
        '?18' => 'DECPFF',        # Send FF to printer after print screen (set); No char after PS (reset)
        '?19' => 'DECPEX',        # Print screen: prints full screen (set); prints scroll region (reset)
        '?25' => 'DECTCEM',       # Cursor on (set); Cursor off (reset)
      }

      # supported character sequences
      @_funcs = {
        'BS'      => :_code_BS,      # backspace one column
        'CR'      => :_code_CR,      # carriage return
        'DA'      => :_code_DA,      # return ESC [ ? 6 c (VT102)
        'DL'      => :_code_DL,      # delete lines
        'ED'      => :_code_ED,      # erase display
        'EL'      => :_code_EL,      # erase line
        'FF'      => :_code_LF,      # line feed
        'HT'      => :_code_HT,      # horizontal tab to next tab stop
        'IL'      => :_code_IL,      # insert blank lines
        'LF'      => :_code_LF,      # line feed
        'PM'      => :_code_PM,      # privacy message (ended by ST)
        'RI'      => :_code_RI,      # reverse line feed
        'RM'      => :_code_RM,      # reset mode
        'SI'      => nil,            # activate G0 character set
        'SM'      => :_code_SM,      # set mode
        'SO'      => nil,            # activate G1 character set & CR
        'ST'      => nil,            # string terminator
        'VT'      => :_code_LF,      # line feed
        'APC'     => :_code_APC,     # application program command (ended by ST)
        'BEL'     => :_code_BEL,     # beep
        'CAN'     => :_code_CAN,     # interrupt escape sequence
        'CHA'     => :_code_CHA,     # move cursor to column in current row
        'CNL'     => :_code_CNL,     # move cursor down and to column 1
        'CPL'     => :_code_CPL,     # move cursor up and to column 1
        'CRM'     => nil,            # control representation mode
        'CSI'     => :_code_CSI,     # equivalent to ESC [
        'CUB'     => :_code_CUB,     # move cursor left
        'CUD'     => :_code_CUD,     # move cursor down
        'CUF'     => :_code_CUF,     # move cursor right
        'CUP'     => :_code_CUP,     # move cursor to row, column
        'CUU'     => :_code_CUU,     # move cursor up
        'DCH'     => :_code_DCH,     # delete characters on current line
        'DCS'     => :_code_DCS,     # device control string (ended by ST)
        'DEL'     => :_code_IGN,     # ignored
        'DSR'     => :_code_DSR,     # device status report
        'EBM'     => nil,            # editing boundary mode
        'ECH'     => :_code_ECH,     # erase characters on current line
        'ENQ'     => nil,            # trigger answerback message
        'ERM'     => nil,            # erasure mode
        'ESC'     => :_code_ESC,    # start escape sequence
        'HEM'     => nil,            # horizontal editing mode
        'HPA'     => :_code_CHA,     # move cursor to column in current row
        'HPR'     => :_code_CUF,     # move cursor right
        'HTS'     => :_code_HTS,     # set tab stop at current column
        'HVP'     => :_code_CUP,     # move cursor to row, column
        'ICH'     => :_code_ICH,     # insert blank characters
        'IGN'     => :_code_IGN,     # ignored control sequence
        'IND'     => :_code_LF,      # line feed
        'IRM'     => nil,            # insert/replace mode
        'KAM'     => nil,            # keyboard action mode
        'LNM'     => nil,            # line feed / newline mode
        'LS2'     => nil,            # invoke G2 charset
        'LS3'     => nil,            # invoke G3 charset
        'NEL'     => :_code_NEL,     # newline
        'NUL'     => :_code_IGN,     # ignored
        'OSC'     => :_code_OSC,     # operating system command
        'PUM'     => nil,            # positioning unit mode
        'RIS'     => :_code_RIS,     # reset
        'SGR'     => :_code_SGR,     # set graphic rendition
        'SOS'     => nil,            # start of string
        'SRM'     => nil,            # send/receive mode (echo on/off)
        'SS2'     => nil,            # select G2 charset for next char only
        'SS3'     => nil,            # select G3 charset for next char only
        'SUB'     => :_code_CAN,     # interrupt escape sequence
        'TBC'     => :_code_TBC,     # clear tab stop (CSI 3 g = clear all stops)
        'TSM'     => nil,            # tabulation stop mode
        'TTM'     => nil,            # transfer termination mode
        'VEM'     => nil,            # vertical editing mode
        'VPA'     => :_code_VPA,     # move to row (current column)
        'VPR'     => :_code_CUD,     # move cursor down
        'XON'     => :_code_XON,     # resume transmission
        'FEAM'    => nil,            # format effector action mode
        'FETM'    => nil,            # format effector transfer mode
        'GATM'    => nil,            # guarded-area transfer mode
        'LS1R'    => nil,            # invoke G1 charset as GR
        'LS2R'    => nil,            # invoke G2 charset as GR
        'LS3R'    => nil,            # invoke G3 charset as GR
        'MATM'    => nil,            # multiple area transfer mode
        'SATM'    => nil,            # selected area transfer mode
        'SRTM'    => nil,            # status-reporting transfer mode
        'XOFF'    => :_code_XOFF,    # stop transmission, ignore characters
        'CSDFL'   => nil,            # select default charset (ISO646/8859-1)
        'CUPRS'   => :_code_CUPRS,   # restore cursor position
        'CUPSV'   => :_code_CUPSV,   # save cursor position
        'DECID'   => :_code_DA,      # DEC private ID; return ESC [ ? 6 c (VT102)
        'DECLL'   => nil,            # set keyboard LEDs
        'DECOM'   => nil,            # relative/absolute coordinate mode
        'DECRC'   => :_code_DECRC,   # restore most recently saved state
        'DECSC'   => :_code_DECSC,   # save state (position, charset, attributes)
        'G0DFL'   => nil,            # G0 charset = default mapping (ISO8859-1)
        'G0GFX'   => nil,            # G0 charset = VT100 graphics mapping
        'G0ROM'   => nil,            # G0 charset = null mapping (straight to ROM)
        'G0TXT'   => nil,            # G0 charset = ASCII mapping
        'G0USR'   => nil,            # G0 charset = user defined mapping
        'G1DFL'   => nil,            # G1 charset = default mapping (ISO8859-1)
        'G1GFX'   => nil,            # G1 charset = VT100 graphics mapping
        'G1ROM'   => nil,            # G1 charset = null mapping (straight to ROM)
        'G1TXT'   => nil,            # G1 charset = ASCII mapping
        'G1USR'   => nil,            # G1 charset = user defined mapping
        'G2DFL'   => nil,            # G2 charset = default mapping (ISO8859-1)
        'G2GFX'   => nil,            # G2 charset = VT100 graphics mapping
        'G2ROM'   => nil,            # G2 charset = null mapping (straight to ROM)
        'G2USR'   => nil,            # G2 charset = user defined mapping
        'G3DFL'   => nil,            # G3 charset = default mapping (ISO8859-1)
        'G3GFX'   => nil,            # G3 charset = VT100 graphics mapping
        'G3ROM'   => nil,            # G3 charset = null mapping (straight to ROM)
        'G3USR'   => nil,            # G3 charset = user defined mapping
        'CSUTF8'  => nil,            # select UTF-8 (obsolete)
        'DECALN'  => :_code_DECALN,  # DEC alignment test - fill screen with E's
        'DECANM'  => nil,            # ANSI/VT52 mode
        'DECARM'  => nil,            # auto repeat mode
        'DECAWM'  => nil,            # auto wrap mode
        'DECCKM'  => nil,            # cursor key mode
        'DECPAM'  => nil,            # set application keypad mode
        'DECPEX'  => nil,            # print screen / scrolling region
        'DECPFF'  => nil,            # sent FF after print screen, or not
        'DECPNM'  => nil,            # set numeric keypad mode
        'DECCOLM' => nil,            # 132 column mode
        'DECINLM' => nil,            # interlace mode
        'DECSCLM' => nil,            # jump/smooth scroll mode
        'DECSCNM' => nil,            # reverse/normal screen mode
        'DECSTBM' => :_code_DECSTBM, # set scrolling region
        'DECTCEM' => :_code_DECTCEM, # Cursor on (set); Cursor off (reset)
      }

      @_callbacks = {
        'BELL'              => nil,  # bell character received
        'CLEAR'             => nil,  # screen cleared
        'OUTPUT'            => nil,  # data to be sent back to originator
        'ROWCHANGE'         => nil,  # screen row changed
        'SCROLL_DOWN'       => nil,  # text about to move up (par=top row)
        'SCROLL_UP'         => nil,  # text about to move down (par=bott.)
        'UNKNOWN'           => nil,  # unknown character / sequence
        'STRING'            => nil,  # string received
        'XICONNAME'         => nil,  # xterm icon name changed
        'XWINTITLE'         => nil,  # xterm window title changed
        'LINEFEED'          => nil,  # line feed about to be processed
      }

      # stored arguments for callbacks
      @_callbackarg = {}

      # saved state for DECSC/DECRC
      @_decsc = []

      # saved state for CUPSV/CUPRS
      @_cupsv = []

      # state is XON (characters accepted)
      @_xon = 1

      # tab stops
      @_tabstops = []

      @cols, @rows = (cols > 0 ? cols : 80),
                     (rows > 0 ? rows : 24)

      reset
    end

    # Call a callback function with the given parameters.
    #
    def callback_call(callback, arg1 = 0, arg2 = 0)
      if (func = @_callbacks[callback])
        priv = @_callbackarg[callback]
        func.call(self, callback, arg1, arg2, priv)
      end
    end

    # Set a callback function.
    #
    def callback_set(callback, ref, arg = nil)
      @_callbacks[callback] = ref
      @_callbackarg[callback] = arg
    end

    # Reset the terminal to "power-on" values.
    #
    def reset
      @x = 1                               # default X position: 1
      @y = 1                               # default Y position: 1

      @attr = DEFAULT_ATTR_PACKED

      @ti = ''                             # default: blank window title
      @ic = ''                             # default: blank icon title

      @srt = 1                             # scrolling region top: row 1
      @srb = @rows                         # scrolling region bottom

      @opts = {}                           # blank all options
      @opts['LINEWRAP'] = 0                # line wrapping off
      @opts['LFTOCRLF'] = 0                # don't map LF -> CRLF
      @opts['IGNOREXOFF'] = 1              # ignore XON/XOFF by default

      @scrt = []                           # blank screen text
      @scra = []                           # blank screen attributes

      (1 .. @rows).each do |i|
        @scrt[i] = "\000" * @cols          # set text to NUL
        @scra[i] = @attr * @cols           # set attributes to default
      end

      @_tabstops = []                      # reset tab stops
      i = 1
      while i < @cols
        @_tabstops[i] = 1
        i += 8
      end


      @_buf = nil                          # blank the esc-sequence buffer
      @_inesc = ''                         # not in any escape sequence
      @_xon  = 1                           # state is XON (chars accepted)

      @cursor = 1                          # turn cursor on
    end

    # Resize the terminal.
    #
    def resize(cols, rows)
      callback_call 'CLEAR'
      @cols, @rows = cols, rows
      reset
    end

    # Return the current number of columns.
    # Return the current number of rows.
    attr_reader :cols, :rows

    # Return the current terminal size.
    #
    def size
      [cols, rows]
    end

    # Return the current cursor X/Y co-ordinates
    #
    attr_reader :x, :y

    # Return the current cursor state (true = on, false = off).
    #
    def cursor?
      @cursor == 1
    end

    # Return the current xterm title text.
    #
    def xtitle
      @ti
    end

    # Return the current xterm icon text.
    #
    def xicon
      @ic
    end

    # Return the current terminal status.
    #
    def status
      [@x, @y, @attr, @ti, @ic]
    end

    # Process the given string, updating the terminal object and calling any
    # necessary callbacks on the way.
    #
    def process(string)
      while !string.empty?
        if @_buf                           # in escape sequence
          if string.sub!(/\A(.)/m, '')
            ch = $1
            if ch.match(/[\x00-\x1F]/mn)
              _process_ctl(ch)
            else
              @_buf += ch
              _process_escseq
            end
          end
        else                               # not in escape sequence
          if string.sub!(/\A([^\x00-\x1F\x7F\x9B]+)/mn, '')
            _process_text($1)
          elsif string.sub!(/\A(.)/m, '')
            _process_ctl($1)
          end
        end
      end
    end

    # Return the current value of the given option, or nil if it doesn't exist.
    #
    def option_read(option)
      @opts[option]
    end

    # Set the value of the given option to the given value, returning the old
    # value or undef if an invalid option was given.
    #
    def option_set(option, value)
      return nil unless @opts.has_key?(option)

      prev = @opts[option]
      @opts[option] = value
      prev
    end

    # Return the attributes of the given row, or undef if out of range.
    #
    def row_attr(row, startcol = nil, endcol = nil)
      return nil unless (1 .. @rows).cover?(row)
      data = @scra[row].dup

      if startcol && endcol
        data = data[(startcol - 1) * 2, ((endcol - startcol) + 1) * 2]
      end

      data
    end

    # Return the textual contents of the given row, or undef if out of range.
    #
    def row_text(row, startcol = nil, endcol = nil)
      return nil if (row < 1) || (row > @rows)

      text = @scrt[row].dup

      if startcol && endcol
        text = text[startcol - 1, (endcol - startcol) + 1]
      end
      text
    end

    # Return the textual contents of the given row, or undef if out of range,
    # with unused characters represented as a space instead of \0.
    #
    def row_plaintext(row, startcol = nil, endcol = nil)
      return nil if (row < 1) || (row > @rows)

      text = @scrt[row].dup
      text.gsub!(/\0/, ' ')

      if startcol && endcol
        text = text[startcol - 1, (endcol - startcol) + 1]
      end

      text
    end

    # Return a set of SGR escape sequences that will change colours and
    # attributes from "source" to "dest" (packed attributes).
    #
    def sgr_change(source = DEFAULT_ATTR_PACKED, dest = DEFAULT_ATTR_PACKED)
      out, off, on = '', {}, {}

      return '' if source == dest
      return "\e[m" if dest == DEFAULT_ATTR_PACKED

      sfg, sbg, sbo, sfa, sst, sul, sbl, srv = attr_unpack(source)
      dfg, dbg, dbo, dfa, _dst, dul, dbl, drv = attr_unpack(dest)

      if sfg != dfg || sbg != dbg
        out += sprintf("\e[m\e[3%d;4%dm", dfg, dbg)
        sbo = sfa = sst = sul = sbl = srv = 0
      end

      if sbo > dbo || sfa > dfa
        off['22'] = 1
        sbo = sfa = 0
      end

      off['24'] = 1 if sul > dul
      off['25'] = 1 if sbl > dbl
      off['27'] = 1 if srv > drv

      if off.size > 2
        out += "\e[m"
        sbo = sfa = sst = sul = sbl = srv = 0
      elsif off.size > 0
        out += "\e[" + off.keys.join(';') + "m"
      end

      on['1'] = 1 if dbo > sbo
      on['2'] = 1 if (dfa > sfa) && !(dbo > sbo)
      on['4'] = 1 if dul > sul
      on['5'] = 1 if dbl > sbl
      on['7'] = 1 if drv > srv

      unless on.empty?
        out += "\e[" + on.keys.join(';') + "m"
      end

      out
    end

    # Return the textual contents of the given row, or undef if out of range,
    # with unused characters represented as a space instead of \0, and any
    # colour or attribute changes expressed by the relevant SGR escape
    # sequences.
    #
    def row_sgrtext(row, startcol = 1, endcol = nil)
      return nil if row < 1 || row > @rows

      endcol ||= @cols

      return nil if endcol < startcol
      return nil if startcol < 1 || endcol > @cols

      row_text = @scrt[row]
      row_attr = @scra[row]

      text = ''
      attr_cur = DEFAULT_ATTR_PACKED

      while startcol <= endcol
        char = row_text[startcol - 1, 1]
        char.gsub!(/\0/, '')
        char = ' ' unless char.match(/./)
        attr_next = row_attr[(startcol - 1) * 2, 2]
        text += sgr_change(attr_cur, attr_next) + char
        attr_cur = attr_next

        startcol += 1
      end

      attr_next = DEFAULT_ATTR_PACKED
      text += sgr_change(attr_cur, attr_next)

      text
    end

    # Process a string of plain text, with no special characters in it.
    #
    def _process_text(text)
      return if @_xon == 0

      width = (@cols + 1) - @x

      if @opts['LINEWRAP'] == 0
        return if width < 1
        text = text[0, width]
        @scrt[@y][@x - 1, text.size] = text
        @scra[@y][2 * (@x - 1), 2 * text.size] = @attr * text.size
        @x += text.size
        @x = @cols if @x > @cols

        callback_call('ROWCHANGE', @y)
        return
      end

      while !text.empty?                   # line wrapping enabled
        if width > 0
          segment = text[0, width]
          text[0, width] = ''
          @scrt[@y][@x - 1, segment.size] = segment
          @scra[@y][2 * (@x - 1), 2 * segment.size] = @attr * segment.size
          @x += segment.size
        else
          if @x > @cols                    # wrap to next line
            callback_call('ROWCHANGE', @y, 0)
            callback_call('LINEFEED', @y, 0)
            @x = 1
            _move_down
          end
        end
        width = (@cols + 1) - @x
      end
      callback_call('ROWCHANGE', @y, 0)
    end

    # Process a control character.
    #
    def _process_ctl(ctl)
      name = @_ctlseq[ctl]
      return if name.nil?                  # ignore unknown characters

      #If we're in XOFF mode, ifgnore anything other than XON
      if @_xon == 0
        return if name != 'XON'
      end


      symbol = @_funcs[name]
      if symbol.nil?
        callback_call('UNKNOWN', name, ctl)
      else
        m = method(symbol)
        send(symbol, *([name].first(m.arity)))
      end
    end

    # Check the escape-sequence buffer, and process it if necessary.
    #
    def _process_escseq
      params = []

      return if @_buf.nil? || @_buf.empty?
      return if @_xon == 0

      if @_inesc == 'OSC'
        if @_buf.match(/\A0;([^\007]*)(?:\007|\033\\)/m)
          dat = $1                         # icon & window
          callback_call('XWINTITLE', dat)
          callback_call('XICONNAME', dat)
          @ic = dat
          @ti = dat
          @_buf = nil
          @_inesc = ''
        elsif @_buf.match(/\A1;([^\007]*)(?:\007|\033\\)/m)
          dat = $1                         # set icon name
          callback_call('XICONNAME', dat)
          @ic = dat
          @_buf = nil
          @_inesc = ''
        elsif @_buf.match(/\A2;([^\007]*)(?:\007|\033\\)/m)
          dat = $1                         # set window title
          callback_call('XWINTITLE', dat)
          @ti = dat
          @_buf = nil
          @_inesc = ''
        elsif @_buf.match(/\A\d+;([^\007]*)(?:\007|\033\\)/m)
                                           # unknown OSC
          callback_call('UNKNOWN', 'OSC', "\033]" + @_buf)
          @_buf = nil
          @_inesc = ''
        elsif @_buf.size > 1024            # OSC too long
          callback_call('UNKNOWN', 'OSC', "\033]" + @_buf)
          @_buf = nil
          @_inesc = ''
        end
      elsif @_inesc == 'CSI'               # in CSI sequence
        @_csiseq.keys.each do |suffix|
          next if @_buf.size < suffix.size
          next if @_buf[@_buf.size - suffix.size, suffix.size] != suffix

          @_buf = @_buf[0, @_buf.size - suffix.size]

          name = @_csiseq[suffix]
          func = @_funcs[name]

          if func.nil?                     # unsupported sequence
            callback_call('UNKNOWN', name, "\033[" + @_buf + suffix)
            @_buf = nil
            @_inesc = ''
            return
          end

          params = @_buf.split(';').map(&:to_i)
          @_buf = nil
          @_inesc = ''

          send(func, *params)
          return
        end

        if @_buf.size > 64                 # abort CSI sequence if too long
          callback_call('UNKNOWN', 'CSI', "\033[" + @_buf)
          @_buf = nil
          @_inesc = ''
        end
      elsif @_inesc =~ /_ST\z/m
        if @_buf.sub!(/\033\\\z/m, '')
          @_inesc.sub!(/_ST\z/m, '')
          callback_call('STRING', @_inesc, @_buf)
          @_buf = nil
          @_inesc = ''
        elsif @_buf.size > 1024            # string too long
          @_inesc.sub!(/_ST\z/m, '')
          callback_call('STRING', @_inesc, @_buf)
          @_buf = nil
          @_inesc = ''
        end
      else                                 # in ESC sequence
        @_escseq.keys.each do |prefix|
          next if @_buf[0, prefix.size] != prefix

          name = @_escseq[prefix]
          func = @_funcs[name]
          if func.nil?                     # unsupported sequence
            callback_call('UNKNOWN', name, "\033" + @_buf)
            @_buf = nil
            @_inesc = ''
            return
          end
          @_buf = nil
          @_inesc = ''
          send(func)
          return
        end

        if @_buf.size > 8                  # abort ESC sequence if too long
          callback_call('UNKNOWN', 'ESC', "\033" + @_buf)
          @_buf = nil
          @_inesc = ''
        end
      end
    end

    # Scroll the scrolling region up such that the text in the scrolling region
    # moves down, by the given number of lines.
    #
    def _scroll_up(lines)
      return if lines < 1
      callback_call('SCROLL_UP', @srb, lines)

      i = @srb
      while i >= @srt + lines
        @scrt[i] = @scrt[i - lines]
        @scra[i] = @scra[i - lines]
        i -= 1
      end

      attr = DEFAULT_ATTR_PACKED

      i = @srt
      while (i <= @srb) && (i < (@srt + lines))
        @scrt[i] = "\000" * @cols          # blank new lines
        @scra[i] = attr * @cols            # wipe attributes of new lines
        i += 1
      end
    end

    # Scroll the scrolling region down such that the text in the scrolling region
    # moves up, by the given number of lines.
    #
    def _scroll_down(lines)
      callback_call('SCROLL_DOWN', @srt, lines)

      i = @srt
      while i <= (@srb - lines)
        @scrt[i] = @scrt[i + lines]
        @scra[i] = @scra[i + lines]
        i += 1
      end

      attr = DEFAULT_ATTR_PACKED

      i = @srb
      while (i >= @srt) && (i > (@srb - lines))
        @scrt[i] = "\000" * @cols      # blank new lines
        @scra[i] = attr * @cols        # wipe attributes of new lines
        i -= 1
      end
    end

    # Move the cursor up the given number of lines, without triggering a GOTO
    # callback, taking scrolling into account.
    #
    def _move_up(num = 1)
      num = [num, 1].max

      @y -= num
      return if @y >= @srt

      _scroll_up(@srt - @y)                # scroll
      @y = @srt
    end

    # Move the cursor down the given number of lines, without triggering a GOTO
    # callback, taking scrolling into account.
    #
    def _move_down(num = 1)
      num = [num, 1].max

      @y += num
      return if @y <= @srb

      _scroll_down(@y - @srb)              # scroll
      @y = @srb
    end

    def _code_BEL                          # beep
      if @_buf && @_inesc == 'OSC'
        # CSI OSC can be terminated with a BEL
        @_buf += "\007"
        _process_escseq()
      else
        callback_call('BELL')
      end
    end

    def _code_BS                           # move left 1 character
      @x -= 1
      @x = 1 if @x < 1
    end

    def _code_CAN                          # cancel escape sequence
      @_buf = nil
      @_inesc = ''
    end

    def _code_TBC(num = nil)               # clear tab stop (CSI 3 g = clear all stops)
      if num == 3
        @_tabstops = []
      else
        @_tabstops[@x] = nil
      end
    end

    def _code_CHA(col = 1)                 # move to column in current row
      return if @x == col

      callback_call('GOTO', col, @y)

      @x = col
      @x = 1 if @x < 1
      @x = @cols if (@x > @cols)
    end

    def _code_CNL(num = 1)                 # move cursor down and to column 1
      callback_call('GOTO', 1, @y + num)
      @x = 1
      _move_down(num)
    end

    def _code_CPL(num = 1)                 # move cursor up and to column 1
      callback_call('GOTO', @x, @y - num)
      @x = 1
      _move_up(num)
    end

    def _code_CR                           # carriage return
      @x = 1
    end

    def _code_CSI                          # ESC [
      @_buf = ''                           # restart ESC buffering
      @_inesc = 'CSI'                      # ...for a CSI, not an ESC
    end

    def _code_CUB(num = 1)                 # move cursor left
      num = [num, 1].max

      callback_call('GOTO', @x - num, @y)

      @x -= num
      @x = [@x, 1].max
    end

    def _code_CUD(num = 1)                 # move cursor down
      num = [num, 1].max
      callback_call('GOTO', @x, @y + num)
      _move_down(num)
    end

    def _code_CUF(num = 1)                 # move cursor right
      num = [num, 1].max
      callback_call('GOTO', @x + num, @y)
      @x += num
      @x = @cols if (@x > @cols)
    end

    def _code_CUP(row = 1, col = 1)        # move cursor to row, column
      row = [row, 1].max
      col = [col, 1].max

      row = @rows if row > @rows
      col = @cols if col > @cols

      callback_call('GOTO', col, row)

      @x, @y = col, row
    end

    def _code_RI                           # reverse line feed
      callback_call('GOTO', @x, @y - 1)
      _move_up
    end

    def _code_CUU(num = 1)                 # move cursor up
      num = [num, 1].max
      callback_call('GOTO', @x, @y - num)
      _move_up(num)
    end

    def _code_DA                           # return ESC [ ? 6 c (VT102)
      callback_call('OUTPUT', "\033[?6c", 0)
    end

    def _code_DCH(num = 1)                 # delete characters on current line
      num = [num, 1].max

      width = @cols + 1 - @x
      todel = num
      todel = width if todel > width

      line = @scrt[@y]
      lsub, rsub = '', ''
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[(@x - 1 + todel) .. -1]
      @scrt[@y] = lsub + rsub + ("\0" * todel)

      line = @scra[@y]
      lsub, rsub = '', ''
      lsub = line[0, 2 * (@x - 1)] if @x > 1
      rsub = line[(2 * (@x - 1 + todel)) .. -1]
      @scra[@y] = lsub + rsub + (DEFAULT_ATTR_PACKED * todel)

      callback_call('ROWCHANGE', @y, 0)
    end

    def _code_DCS                          # device control string (ignored)
      @_buf = ''
      @_inesc = 'DCS_ST'
    end

    def _code_DECSTBM(top = 1, bottom = nil) # set scrolling region
      bottom ||= @rows
      top = [top, 1].max
      bottom = [bottom, 1].max

      top = @rows if top > @rows
      bottom = @rows if bottom > @rows

      (top, bottom = bottom, top) if bottom < top

      @srb, @srt = bottom, top
    end

    def _code_DECTCEM(cursor)              # Cursor on (set); Cursor off (reset)
      @cursor = cursor
    end

    def _code_IGN                          # ignored control sequence
    end

    def _code_DL(lines = 1)                # delete lines
      lines = [lines, 1].max

      attr = DEFAULT_ATTR_PACKED

      scrb = @srb
      scrb = @rows if @y > @srb
      scrb = @srt - 1 if @y < @srt

      row = @y
      while row <= scrb - lines
        @scrt[row] = @scrt[row + lines]
        @scra[row] = @scra[row + lines]
        callback_call('ROWCHANGE', row, 0)
        row += 1
      end

      row = scrb
      while row > (scrb - lines) && row >= @y
        @scrt[row] = "\000" * @cols
        @scra[row] = attr * @cols
        callback_call('ROWCHANGE', row, 0)
        row -= 1
      end
    end

    def _code_DSR(num = 5)                 # device status report
      if num == 6                          # CPR - cursor position report
        callback_call('OUTPUT', "\e[#{@y};#{@x}R", 0)
      elsif num == 5                       # DSR - reply ESC [ 0 n
        callback_call('OUTPUT', "\e[0n", 0)
      end
    end

    def _code_ECH(num = 1)                 # erase characters on current line
      num = [num, 1].max

      width = @cols + 1 - @x
      todel = num
      todel = width if todel > width

      line = @scrt[@y]
      lsub, rsub = '', ''
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[(@x - 1 + todel) .. -1]
      @scrt[@y] = lsub + ("\0" * todel) + rsub


      line = @scra[@y]
      lsub, rsub = '', ''
      lsub = line[0, 2 * (@x - 1)] if @x > 1
      rsub = line[(2 * (@x - 1 + todel)) .. -1]

      @scra[@y] = lsub + (DEFAULT_ATTR_PACKED * todel) + rsub
      callback_call('ROWCHANGE', @y, 0)
    end

    def _code_ED(num = 0)                  # erase display
      attr = DEFAULT_ATTR_PACKED

      # Wipe-cursor-to-end is the same as clear-whole-screen if cursor at top left
      #
      num = 2 if (num == 0) && (@x == 1) && (@y == 1)

      if num == 0                          # 0 = cursor to end
        @scrt[@y] = @scrt[@y][0, @x - 1] + ("\0" * (@cols + 1 - @x))
        @scra[@y] = @scra[@y][0, 2 * (@x - 1)] + (attr * (cols + 1 - @x))
        callback_call('ROWCHANGE', @y, 0)

        row = @y + 1
        while row <= @rows
          @scrt[row] = "\0" * @cols
          @scra[row] = attr * @cols
          callback_call('ROWCHANGE', row, 0)
          row += 1
        end
      elsif num == 1                       # 1 = start to cursor
        row = 1
        while row < @y
          @scrt[row] = "\0" * @cols
          @scra[row] = attr * @cols
          callback_call('ROWCHANGE', row, 0)
          row += 1
        end

        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = (attr * @x) + @scra[@y][2 * @x .. -1]
        callback_call('ROWCHANGE', @y, 0)
      else                                 # 2 = whole display
        callback_call('CLEAR', 0, 0)
        row = 1
        while row <= rows
          @scrt[row] = "\0" * @cols
          @scra[row] = attr * @cols
          row += 1
        end
      end
    end

    def _code_EL(num = 0)                  # erase line
      attr = DEFAULT_ATTR_PACKED

      if num == 0                         # 0 = cursor to end of line
        @scrt[@y] = @scrt[@y][0, @x - 1] + ("\0" * (@cols + 1 - @x))
        @scra[@y] = @scra[@y][0, 2 * (@x - 1)] + (attr * (@cols + 1 - @x))
        callback_call('ROWCHANGE', @y, 0)
      elsif num == 1                      # 1 = start of line to cursor
        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = (attr * @x) + @scra[@y][(2 * @x) .. -1]
        callback_call('ROWCHANGE', @y, 0)
      else                                 # 2 = whole line
        @scrt[@y] = "\0" * @cols
        @scra[@y] = attr * @cols
        callback_call('ROWCHANGE', @y, 0)
      end
    end

    def _code_ESC                         # start escape sequence
      if @_buf && @_inesc.match(/OSC|_ST/)
        # Some sequences are terminated with an ST
        @_buf += "\033"
        _process_escseq
        return
      end

      @_buf = ''                          # set ESC buffer
      @_inesc = 'ESC'                     # ...for ESC, not CSI
    end

    def _code_LF                          # line feed
      _code_CR if @opts['LFTOCRLF'] != 0

      callback_call('LINEFEED', @y, 0)
      _move_down
    end

    def _code_NEL                         # newline
      _code_CR                            # cursor always to start
      _code_LF                            # standard line feed
    end

    def _code_HT                          # horizontal tab to next tab stop
      if @opts['LINEWRAP'] != 0 && @x >= @cols
        callback_call('LINEFEED', @y, 0)
        @x = 1
        _move_down
      end

      newx = @x + 1
      while newx < @cols && @_tabstops[newx] != 1
        newx += 1
      end

      width = (@cols + 1) - @x
      spaces = newx - @x
      spaces = width + 1 if spaces > width

      if spaces > 0
        @x += spaces
        @x = @cols if @x > @cols
      end
    end

    def _code_HTS                         # set tab stop at current column
      @_tabstops[@x] = 1
    end

    def _code_ICH(num = 1)                # insert blank characters
      num = [num, 1].max

      width = @cols + 1 - @x
      toins = num
      toins = width if toins > width

      line = @scrt[@y]
      lsub, rsub = '', ''
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[@x - 1, width - toins]
      @scrt[@y] = lsub + ("\0" * toins) + rsub

      attr = DEFAULT_ATTR_PACKED
      line = @scra[@y]
      lsub, rsub = '', ''
      lsub = line[0, 2 * (@x - 1)] if @x > 1
      rsub = line[2 * (@x - 1), 2 * (width - toins)]
      @scra[@y] = lsub + (attr * toins) + rsub

      callback_call('ROWCHANGE', @y, 0)
    end

    def _code_IL(lines = 1)               # insert blank lines
      lines = [lines, 1].max

      attr = DEFAULT_ATTR_PACKED

      scrb = @srb
      scrb = @rows if @y > @srb
      scrb = @srt - 1 if @y < @srt

      row = scrb
      while row >= y + lines
        @scrt[row] = @scrt[row - lines]
        @scra[row] = @scra[row - lines]
        callback_call('ROWCHANGE', row, 0)

        row -= 1
      end

      row = @y
      while (row <= scrb) && (row < (@y + lines))
        @scrt[row] = "\000" * @cols
        @scra[row] = attr * @cols
        callback_call('ROWCHANGE', row, 0)
        row += 1
      end
    end

    def _code_PM                          # privacy message (ignored)
      @_buf = ''
      @_inesc = 'PM_ST'
    end

    def _code_APC                         # application program command (ignored)
      @_buf = ''
      @_inesc = 'APC_ST'
    end

    def _code_OSC                         # operating system command
      @_buf = ''                          # restart buffering
      @_inesc = 'OSC'                     # ...for OSC, not ESC or CSI
    end

    def _code_RIS                         # reset
      reset
    end

    def _toggle_mode(flag, modes)         # set/reset modes
      # Transcription Note: This isn't really a loop
      fail ArgumentError, "only first mode applied" if modes.size > 1

      modes.each do |mode|
        name = @_modeseq[mode]
        func = nil
        func = @_funcs[name] unless name.nil?

        if func.nil?
          callback_call('UNKNOWN', name, "\033[#{mode}" + (flag ? "h" : "l"))
          @_buf = nil
          @_inesc = ''
          return
        end

        @_buf = nil
        @_inesc = ''
        send(func, flag)
        return
      end
    end

    def _code_RM(*args)                   # reset mode
      _toggle_mode(0, args)
    end

    def _code_SM(*args)                   # set mode
      _toggle_mode(1, args)
    end

    def _code_SGR(*parms)                 # set graphic rendition
      fg, bg, bo, fa, st, ul, bl, rv = attr_unpack(@attr)

      parms = [0] if parms.empty?         # ESC [ m = ESC [ 0 m
      parms.each do |val|
        case val
          when 0                          # reset all attributes
            fg, bg, bo, fa, st, ul, bl, rv = DEFAULT_ATTR
          when 1                          # bold ON
            bo, fa = 1, 0
          when 2                          # faint ON
            bo, fa = 0, 1
          when 4                          # underline ON
            ul = 1
          when 5                          # blink ON
            bl = 1
          when 7                          # reverse video ON
            rv = 1
          when 21..22                     # normal intensity
            bo, fa = 0, 0
          when 24                         # underline OFF
            ul = 0
          when 25                         # blink OFF
            bl = 0
          when 27                         # reverse video OFF
            rv = 0
          when 30..37                     # set foreground colour
            fg = val - 30
          when 38                         # underline on, default fg
            ul, fg = 1, 7
          when 39                         # underline off, default fg
            ul, fg = 0, 7
          when 40..47                     # set background colour
            bg = val - 40
          when  49                        # default background
            bg = 0
        end
      end

      @attr = attr_pack(fg, bg, bo, fa, st, ul, bl, rv)
    end

    def _code_VPA(row = 1)                # move to row (current column)
      return if @y == row

      @y = [row, 1].max
      @y = @rows if @y > @rows
    end

    def _code_DECALN                      # fill screen with E's
      attr = DEFAULT_ATTR_PACKED

      (1 .. @rows).each do |row|
        @scrt[row] = 'E' * @cols
        @scra[row] = attr * @cols
        callback_call('ROWCHANGE', @y, 0)
      end

      @x = @y = 1
    end

    def _code_DECSC                       # save state
      @_decsc.push([@x, @y, @attr, @ti, @ic, @cursor])
    end

    def _code_DECRC                       # restore most recently saved state
      return if @_decsc.empty?
      @x, @y, @attr, @ti, @ic, @cursor = @_decsc.pop
    end

    def _code_CUPSV                       # save cursor position
      @_cupsv.push([@x, @y])
    end

    def _code_CUPRS                       # restore cursor position
      return if @_cupsv.empty?
      @x, @y = @_cupsv.pop
    end

    def _code_XON                         # resume character processing
      @_xon = 1
    end

    def _code_XOFF                        # stop character processing
      return if @opts['IGNOREXOFF'] == 1
      @_xon = 0
    end
  end
end
