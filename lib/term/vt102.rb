# Term::VT102 - module for VT102 emulation in Ruby
#
# Ported from Andrew Wood's Perl module, 'Term::VT102'.
#
# Copyright (C) Mike Owens
# Copyright (C) Andrew Wood
# NO WARRANTY - see LICENSE.txt
#

require 'term/vt102/version'
require 'term/vt102/decparser'

module Term
  class VT102
    CTL_SEQ = {                # control characters
      "\000" => :NUL,          # ignored
      "\005" => :ENQ,          # trigger answerback message
      "\007" => :BEL,          # beep
      "\010" => :BS,           # backspace one column
      "\011" => :HT,           # horizontal tab to next tab stop
      "\012" => :LF,           # line feed
      "\013" => :VT,           # line feed
      "\014" => :FF,           # line feed
      "\015" => :CR,           # carriage return
      "\016" => :SO,           # activate G1 character set & newline
      "\017" => :SI,           # activate G0 character set
      "\021" => :XON,          # resume transmission
      "\023" => :XOFF,         # stop transmission, ignore characters
      "\030" => :CAN,          # interrupt escape sequence
      "\032" => :SUB,          # interrupt escape sequence
      "\033" => :ESC,          # start escape sequence
      "\177" => :DEL,          # ignored
      "\233" => :CSI           # equivalent to ESC [
    }.freeze

    ESC_SEQ = {                # escape sequences
     'c'  => :RIS,             # reset
     'D'  => :IND,             # line feed
     'E'  => :NEL,             # newline
     'H'  => :HTS,             # set tab stop at current column
     'M'  => :RI,              # reverse line feed
     'Z'  => :DECID,           # DEC private ID; return ESC [ ? 6 c (VT102)
     '7'  => :DECSC,           # save state (position, charset, attributes)
     '8'  => :DECRC,           # restore most recently saved state
     '['  => :CSI,             # control sequence introducer
     '[[' => :IGN,             # ignored control sequence
     '%@' => :CSDFL,           # select default charset (ISO646/8859-1)
     '%G' => :CSUTF8,          # select UTF-8
     '%8' => :CSUTF8,          # select UTF-8 (obsolete)
     '#8' => :DECALN,          # DEC alignment test - fill screen with E's
     '(8' => :G0DFL,           # G0 charset = default mapping (ISO8859-1)
     '(0' => :G0GFX,           # G0 charset = VT100 graphics mapping
     '(U' => :G0ROM,           # G0 charset = null mapping (straight to ROM)
     '(K' => :G0USR,           # G0 charset = user defined mapping
     '(B' => :G0TXT,           # G0 charset = ASCII mapping
     ')8' => :G1DFL,           # G1 charset = default mapping (ISO8859-1)
     ')0' => :G1GFX,           # G1 charset = VT100 graphics mapping
     ')U' => :G1ROM,           # G1 charset = null mapping (straight to ROM)
     ')K' => :G1USR,           # G1 charset = user defined mapping
     ')B' => :G1TXT,           # G1 charset = ASCII mapping
     '*8' => :G2DFL,           # G2 charset = default mapping (ISO8859-1)
     '*0' => :G2GFX,           # G2 charset = VT100 graphics mapping
     '*U' => :G2ROM,           # G2 charset = null mapping (straight to ROM)
     '*K' => :G2USR,           # G2 charset = user defined mapping
     '+8' => :G3DFL,           # G3 charset = default mapping (ISO8859-1)
     '+0' => :G3GFX,           # G3 charset = VT100 graphics mapping
     '+U' => :G3ROM,           # G3 charset = null mapping (straight to ROM)
     '+K' => :G3USR,           # G3 charset = user defined mapping
     '>'  => :DECPNM,          # set numeric keypad mode
     '='  => :DECPAM,          # set application keypad mode
     'N'  => :SS2,             # select G2 charset for next char only
     'O'  => :SS3,             # select G3 charset for next char only
     'P'  => :DCS,             # device control string (ended by ST)
     'X'  => :SOS,             # start of string
     '^'  => :PM,              # privacy message (ended by ST)
     '_'  => :APC,             # application program command (ended by ST)
     "\\" => :ST,              # string terminator
     'n'  => :LS2,             # invoke G2 charset
     'o'  => :LS3,             # invoke G3 charset
     '|'  => :LS3R,            # invoke G3 charset as GR
     '}'  => :LS2R,            # invoke G2 charset as GR
     '~'  => :LS1R,            # invoke G1 charset as GR
     ']'  => :OSC,             # operating system command
     'g'  => :BEL,             # alternate BEL
    }.freeze

    CSI_SEQ = {
      '[' => :IGN,             # ignored control sequence
      '@' => :ICH,             # insert blank characters
      'A' => :CUU,             # move cursor up
      'B' => :CUD,             # move cursor down
      'C' => :CUF,             # move cursor right
      'D' => :CUB,             # move cursor left
      'E' => :CNL,             # move cursor down and to column 1
      'F' => :CPL,             # move cursor up and to column 1
      'G' => :CHA,             # move cursor to column in current row
      'H' => :CUP,             # move cursor to row, column
      'J' => :ED,              # erase display
      'K' => :EL,              # erase line
      'L' => :IL,              # insert blank lines
      'M' => :DL,              # delete lines
      'P' => :DCH,             # delete characters on current line
      'X' => :ECH,             # erase characters on current line
      'a' => :HPR,             # move cursor right
      'c' => :DA,              # return ESC [ ? 6 c (VT102)
      'd' => :VPA,             # move to row (current column)
      'e' => :VPR,             # move cursor down
      'f' => :HVP,             # move cursor to row, column
      'g' => :TBC,             # clear tab stop (CSI 3 g = clear all stops)
      'h' => :SM,              # set mode
      'l' => :RM,              # reset mode
      'm' => :SGR,             # set graphic rendition
      'n' => :DSR,             # device status report
      'q' => :DECLL,           # set keyboard LEDs
      'r' => :DECSTBM,         # set scrolling region to (top, bottom) rows
      's' => :CUPSV,           # save cursor position
      'u' => :CUPRS,           # restore cursor position
      '`' => :HPA              # move cursor to column in current row
    }.freeze

    MODE_SEQ = {             # ANSI Specified Modes
      '0'   => :IGN,            # Error (Ignored)
      '1'   => :GATM,           # guarded-area transfer mode (ignored)
      '2'   => :KAM,            # keyboard action mode (always reset)
      '3'   => :CRM,            # control representation mode (always reset)
      '4'   => :IRM,            # insertion/replacement mode (always reset)
      '5'   => :SRTM,           # status-reporting transfer mode
      '6'   => :ERM,            # erasure mode (always set)
      '7'   => :VEM,            # vertical editing mode (ignored)
      '10'  => :HEM,           # horizontal editing mode
      '11'  => :PUM,           # positioning unit mode
      '12'  => :SRM,           # send/receive mode (echo on/off)
      '13'  => :FEAM,          # format effector action mode
      '14'  => :FETM,          # format effector transfer mode
      '15'  => :MATM,          # multiple area transfer mode
      '16'  => :TTM,           # transfer termination mode
      '17'  => :SATM,          # selected area transfer mode
      '18'  => :TSM,           # tabulation stop mode
      '19'  => :EBM,           # editing boundary mode
      '20'  => :LNM,           # Line Feed / New Line Mode
                             # DEC Private Modes
      '?0'  => :IGN,           # Error (Ignored)
      '?1'  => :DECCKM,        # Cursorkeys application (set); Cursorkeys normal (reset)
      '?2'  => :DECANM,        # ANSI (set); VT52 (reset)
      '?3'  => :DECCOLM,       # 132 columns (set); 80 columns (reset)
      '?4'  => :DECSCLM,       # Jump scroll (set); Smooth scroll (reset)
      '?5'  => :DECSCNM,       # Reverse screen (set); Normal screen (reset)
      '?6'  => :DECOM,         # Sets relative coordinates (set); Sets absolute coordinates (reset)
      '?7'  => :DECAWM,        # Auto Wrap
      '?8'  => :DECARM,        # Auto Repeat
      '?9'  => :DECINLM,       # Interlace
      '?18' => :DECPFF,        # Send FF to printer after print screen (set); No char after PS (reset)
      '?19' => :DECPEX,        # Print screen: prints full screen (set); prints scroll region (reset)
      '?25' => :DECTCEM,       # Cursor on (set); Cursor off (reset)
    }.freeze

    METHOD_MAP = {
      :BS      => :_code_BS,      # backspace one column
      :CR      => :_code_CR,      # carriage return
      :DA      => :_code_DA,      # return ESC [ ? 6 c (VT102)
      :DL      => :_code_DL,      # delete lines
      :ED      => :_code_ED,      # erase display
      :EL      => :_code_EL,      # erase line
      :FF      => :_code_LF,      # line feed
      :HT      => :_code_HT,      # horizontal tab to next tab stop
      :IL      => :_code_IL,      # insert blank lines
      :LF      => :_code_LF,      # line feed
      :PM      => :_code_PM,      # privacy message (ended by ST)
      :RI      => :_code_RI,      # reverse line feed
      :RM      => :_code_RM,      # reset mode
      :SI      => nil,            # activate G0 character set
      :SM      => :_code_SM,      # set mode
      :SO      => nil,            # activate G1 character set & CR
      :ST      => nil,            # string terminator
      :VT      => :_code_LF,      # line feed
      :APC     => :_code_APC,     # application program command (ended by ST)
      :BEL     => :_code_BEL,     # beep
      :CAN     => :_code_CAN,     # interrupt escape sequence
      :CHA     => :_code_CHA,     # move cursor to column in current row
      :CNL     => :_code_CNL,     # move cursor down and to column 1
      :CPL     => :_code_CPL,     # move cursor up and to column 1
      :CRM     => nil,            # control representation mode
      :CSI     => :_code_CSI,     # equivalent to ESC [
      :CUB     => :_code_CUB,     # move cursor left
      :CUD     => :_code_CUD,     # move cursor down
      :CUF     => :_code_CUF,     # move cursor right
      :CUP     => :_code_CUP,     # move cursor to row, column
      :CUU     => :_code_CUU,     # move cursor up
      :DCH     => :_code_DCH,     # delete characters on current line
      :DCS     => :_code_DCS,     # device control string (ended by ST)
      :DEL     => :_code_IGN,     # ignored
      :DSR     => :_code_DSR,     # device status report
      :EBM     => nil,            # editing boundary mode
      :ECH     => :_code_ECH,     # erase characters on current line
      :ENQ     => nil,            # trigger answerback message
      :ERM     => nil,            # erasure mode
      :ESC     => :_code_ESC,    # start escape sequence
      :HEM     => nil,            # horizontal editing mode
      :HPA     => :_code_CHA,     # move cursor to column in current row
      :HPR     => :_code_CUF,     # move cursor right
      :HTS     => :_code_HTS,     # set tab stop at current column
      :HVP     => :_code_CUP,     # move cursor to row, column
      :ICH     => :_code_ICH,     # insert blank characters
      :IGN     => :_code_IGN,     # ignored control sequence
      :IND     => :_code_LF,      # line feed
      :IRM     => nil,            # insert/replace mode
      :KAM     => nil,            # keyboard action mode
      :LNM     => nil,            # line feed / newline mode
      :LS2     => nil,            # invoke G2 charset
      :LS3     => nil,            # invoke G3 charset
      :NEL     => :_code_NEL,     # newline
      :NUL     => :_code_IGN,     # ignored
      :OSC     => :_code_OSC,     # operating system command
      :PUM     => nil,            # positioning unit mode
      :RIS     => :_code_RIS,     # reset
      :SGR     => :_code_SGR,     # set graphic rendition
      :SOS     => nil,            # start of string
      :SRM     => :_code_SRM,     # send/receive mode (echo on/off)
      :SS2     => nil,            # select G2 charset for next char only
      :SS3     => nil,            # select G3 charset for next char only
      :SUB     => :_code_CAN,     # interrupt escape sequence
      :TBC     => :_code_TBC,     # clear tab stop (CSI 3 g = clear all stops)
      :TSM     => nil,            # tabulation stop mode
      :TTM     => nil,            # transfer termination mode
      :VEM     => nil,            # vertical editing mode
      :VPA     => :_code_VPA,     # move to row (current column)
      :VPR     => :_code_CUD,     # move cursor down
      :XON     => :_code_XON,     # resume transmission
      :FEAM    => nil,            # format effector action mode
      :FETM    => nil,            # format effector transfer mode
      :GATM    => nil,            # guarded-area transfer mode
      :LS1R    => nil,            # invoke G1 charset as GR
      :LS2R    => nil,            # invoke G2 charset as GR
      :LS3R    => nil,            # invoke G3 charset as GR
      :MATM    => nil,            # multiple area transfer mode
      :SATM    => nil,            # selected area transfer mode
      :SRTM    => nil,            # status-reporting transfer mode
      :XOFF    => :_code_XOFF,    # stop transmission, ignore characters
      :CSDFL   => nil,            # select default charset (ISO646/8859-1)
      :CUPRS   => :_code_CUPRS,   # restore cursor position
      :CUPSV   => :_code_CUPSV,   # save cursor position
      :DECID   => :_code_DA,      # DEC private ID; return ESC [ ? 6 c (VT102)
      :DECLL   => nil,            # set keyboard LEDs
      :DECOM   => nil,            # relative/absolute coordinate mode
      :DECRC   => :_code_DECRC,   # restore most recently saved state
      :DECSC   => :_code_DECSC,   # save state (position, charset, attributes)
      :G0DFL   => nil,            # G0 charset = default mapping (ISO8859-1)
      :G0GFX   => nil,            # G0 charset = VT100 graphics mapping
      :G0ROM   => nil,            # G0 charset = null mapping (straight to ROM)
      :G0TXT   => nil,            # G0 charset = ASCII mapping
      :G0USR   => nil,            # G0 charset = user defined mapping
      :G1DFL   => nil,            # G1 charset = default mapping (ISO8859-1)
      :G1GFX   => nil,            # G1 charset = VT100 graphics mapping
      :G1ROM   => nil,            # G1 charset = null mapping (straight to ROM)
      :G1TXT   => nil,            # G1 charset = ASCII mapping
      :G1USR   => nil,            # G1 charset = user defined mapping
      :G2DFL   => nil,            # G2 charset = default mapping (ISO8859-1)
      :G2GFX   => nil,            # G2 charset = VT100 graphics mapping
      :G2ROM   => nil,            # G2 charset = null mapping (straight to ROM)
      :G2USR   => nil,            # G2 charset = user defined mapping
      :G3DFL   => nil,            # G3 charset = default mapping (ISO8859-1)
      :G3GFX   => nil,            # G3 charset = VT100 graphics mapping
      :G3ROM   => nil,            # G3 charset = null mapping (straight to ROM)
      :G3USR   => nil,            # G3 charset = user defined mapping
      :CSUTF8  => nil,            # select UTF-8 (obsolete)
      :DECALN  => :_code_DECALN,  # DEC alignment test - fill screen with E's
      :DECANM  => nil,            # ANSI/VT52 mode
      :DECARM  => nil,            # auto repeat mode
      :DECAWM  => nil,            # auto wrap mode
      :DECCKM  => nil,            # cursor key mode
      :DECPAM  => nil,            # set application keypad mode
      :DECPEX  => nil,            # print screen / scrolling region
      :DECPFF  => nil,            # sent FF after print screen, or not
      :DECPNM  => nil,            # set numeric keypad mode
      :DECCOLM => nil,            # 132 column mode
      :DECINLM => nil,            # interlace mode
      :DECSCLM => nil,            # jump/smooth scroll mode
      :DECSCNM => nil,            # reverse/normal screen mode
      :DECSTBM => :_code_DECSTBM, # set scrolling region
      :DECTCEM => :_code_DECTCEM, # Cursor on (set); Cursor off (reset)
    }.freeze

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

    def cb_execute(ctl)
      name = CTL_SEQ[ctl.chr]
      if name.nil?
        callback_call(:unknown, :command_raw, ctl)
        return if name.nil?                  # ignore unknown characters
      end

      symbol = METHOD_MAP[name]
      if symbol.nil?
        callback_call(:unknown, :command, name, ctl)
      else
        m = method(symbol)
        send(symbol, *([name].first(m.arity)))
      end
    end

    def cb_esc_dispatch(esc_code)
      esc_string = esc_code.map(&:chr).join

      name = ESC_SEQ[esc_string]
      func = METHOD_MAP[name]
      if func.nil?
        callback_call(:unknown, :esc, esc_code)
      else
        send(func)
      end
    end

    def cb_csi_dispatch(csi_code, *params)
      name = CSI_SEQ[csi_code.chr]
      func = METHOD_MAP[name]
      if func.nil?
        callback_call(:unknown, :csi, csi_code, params)
      else
        # Most CSI functions don't care about private flags.  To keep a sane
        # interface, we just pass the code unless the method has a priv_flags:
        # keyword argument, which if exists, will get an array of Boolean
        # where true means private
        priv_flags = params.map(&:first)
        params.map!(&:last)

        m = method(func)
        has_privarg = m.parameters.find do |arg|
          arg == [:key, :priv_flags] ||
          arg == [:keyreq, :priv_flags]
        end

        if has_privarg
          m.call(*params, priv_flags: priv_flags)
        else
          m.call(*params)
        end
      end
    end

    def cb_print(ch)
      _process_text(ch.chr)
    end

    def cb_osc_start(ch)
      @str_buf = ''
    end

    def cb_osc_put(ch)
      @str_buf << ch.chr
    end

    def cb_osc_end(ch)
      code, *params = @str_buf.split(';')
      case code
        when '0'
          callback_call(:xiconname, params[0])
          callback_call(:xwintitle, params[0])
        when '1'
          callback_call(:xiconname, params[0])
        when '2'
          callback_call(:xwintitle, params[0])
        else
          callback_call(:unknown, :osc, code, params)
      end
    end

    def cb_str_start(string_type, ch)
      @str_buf = ''
    end

    def cb_str_put(string_type, ch)
      @str_buf << ch.chr
    end

    def cb_str_end(string_type, ch)
      callback_call(:string, string_type, @str_buf)
    end

    def xon_command?(command, *args)
      return true if command == :execute && args[0] == 17
      return false
    end

    def parser_callback(command, *args)
      if @xon || xon_command?(command, *args)
        send("cb_#{command}", *args)
      end
    end

    # Constructor function.
    #
    def initialize(cols: 80, rows: 24)
      @parser = Term::DECParser.new(&method(:parser_callback))

      @callbacks = {
        :bell         => nil,  # bell character received
        :goto         => nil,
        :clear        => nil,  # screen cleared
        :output       => nil,  # data to be sent back to originator
        :rowchange    => nil,  # screen row changed
        :echochange   => nil,  # "echo" has been enabled or disabled
        :scroll_down  => nil,  # text about to move up (par=top row)
        :scroll_up    => nil,  # text about to move down (par=bott.)
        :unknown      => nil,  # unknown character / sequence
        :string       => nil,  # string received
        :xiconname    => nil,  # xterm icon name changed
        :xwintitle    => nil,  # xterm window title changed
        :mode         => nil,
        :linefeed     => nil,  # line feed about to be processed
      }

      # saved state for DECSC/DECRC
      @decsc = []

      # saved state for CUPSV/CUPRS
      @cupsv = []

      # state is XON (characters accepted)
      @xon = true
      @echo = true

      # tab stops
      @tabstops = []

      @cols, @rows = (cols > 0 ? cols : 80),
                     (rows > 0 ? rows : 24)

      reset
    end

    # Call a callback function with the given parameters.
    #
    def callback_call(callback, *args)
      unless @callbacks.has_key?(callback)
        fail ArgumentError, "invalid callback #{callback.inspect}"
      end

      if (func = @callbacks[callback])
        func.call(self, callback, *args)
      end
    end

    # Set a callback function.
    #
    def callback_set(callback, &ref)
      unless @callbacks.has_key?(callback)
        fail ArgumentError, "invalid callback #{callback.inspect}"
      end
      @callbacks[callback] = ref
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
      @opts[:linewrap] = false              # line wrapping off
      @opts[:lftocrlf] = false             # don't map LF -> CRLF
      @opts[:ignorexoff] = true            # ignore XON/XOFF by default

      @scrt = []                           # blank screen text
      @scra = []                           # blank screen attributes

      (1 .. @rows).each do |i|
        @scrt[i] = "\000" * @cols          # set text to NUL
        @scra[i] = @attr * @cols           # set attributes to default
      end

      @tabstops = []                      # reset tab stops
      i = 1
      while i < @cols
        @tabstops[i] = true
        i += 8
      end

      @xon = true                        # state is XON (chars accepted)
      @echo = true

      @cursor = true                       # turn cursor on
    end

    # Resize the terminal.
    #
    def resize(cols, rows)
      callback_call(:clear)
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
      @cursor
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

    def process(string)
      @parser.parse(string.encode('ASCII-8BIT'))
    end

    # Return the current value of the given option, or nil if it doesn't exist.
    #
    def option_read(option)
      unless @opts.has_key?(option)
        fail ArgumentError, "invalid option #{option.inspect}"
      end

      @opts[option]
    end

    # Set the value of the given option to the given value, returning the old
    # value or undef if an invalid option was given.
    #
    def option_set(option, value)
      unless @opts.has_key?(option)
        fail ArgumentError, "invalid option #{option.inspect}"
      end

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
      return unless @xon

      width = (@cols + 1) - @x

      if ! @opts[:linewrap]
        return if width < 1
        text = text[0, width]
        @scrt[@y][@x - 1, text.size] = text
        @scra[@y][2 * (@x - 1), 2 * text.size] = @attr * text.size
        @x += text.size
        @x = @cols if @x > @cols

        callback_call(:rowchange, @y)
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
            callback_call(:rowchange, @y, 0)
            callback_call(:linefeed, @y, 0)
            @x = 1
            _move_down
          end
        end
        width = (@cols + 1) - @x
      end
      callback_call(:rowchange, @y, 0)
    end


    # Scroll the scrolling region up such that the text in the scrolling region
    # moves down, by the given number of lines.
    #
    def _scroll_up(lines)
      return if lines < 1
      callback_call(:scroll_up, @srb, lines)

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
      callback_call(:scroll_down, @srt, lines)

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
      callback_call(:bell)
    end

    def _code_BS                           # move left 1 character
      @x -= 1
      @x = 1 if @x < 1
    end

    def _code_TBC(num = nil)               # clear tab stop (CSI 3 g = clear all stops)
      if num == 3
        @tabstops = []
      else
        @tabstops[@x] = nil
      end
    end

    def _code_CHA(col = 1)                 # move to column in current row
      return if @x == col

      callback_call(:goto, col, @y)

      @x = col
      @x = 1 if @x < 1
      @x = @cols if (@x > @cols)
    end

    def _code_CNL(num = 1)                 # move cursor down and to column 1
      callback_call(:goto, 1, @y + num)
      @x = 1
      _move_down(num)
    end

    def _code_CPL(num = 1)                 # move cursor up and to column 1
      callback_call(:goto, @x, @y - num)
      @x = 1
      _move_up(num)
    end

    def _code_CR                           # carriage return
      @x = 1
    end

    def _code_CUB(num = 1)                 # move cursor left
      num = [num, 1].max

      callback_call(:goto, @x - num, @y)

      @x -= num
      @x = [@x, 1].max
    end

    def _code_CUD(num = 1)                 # move cursor down
      num = [num, 1].max
      callback_call(:goto, @x, @y + num)
      _move_down(num)
    end

    def _code_CUF(num = 1)                 # move cursor right
      num = [num, 1].max
      callback_call(:goto, @x + num, @y)
      @x += num
      @x = @cols if (@x > @cols)
    end

    def _code_CUP(row = 1, col = 1)        # move cursor to row, column
      row = [row, 1].max
      col = [col, 1].max

      row = @rows if row > @rows
      col = @cols if col > @cols

      callback_call(:goto, col, row)

      @x, @y = col, row
    end

    def _code_RI                           # reverse line feed
      callback_call(:goto, @x, @y - 1)
      _move_up(1)
    end

    def _code_CUU(num = 1)                 # move cursor up
      num = [num, 1].max
      callback_call(:goto, @x, @y - num)
      _move_up(num)
    end

    def _code_DA                           # return ESC [ ? 6 c (VT102)
      callback_call(:output, "\033[?6c", 0)
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

      callback_call(:rowchange, @y, 0)
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
      @cursor = [1, true].include?(cursor)
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
        callback_call(:rowchange, row, 0)
        row += 1
      end

      row = scrb
      while row > (scrb - lines) && row >= @y
        @scrt[row] = "\000" * @cols
        @scra[row] = attr * @cols
        callback_call(:rowchange, row, 0)
        row -= 1
      end
    end

    def _code_DSR(num = 5)                 # device status report
      if num == 6                          # CPR - cursor position report
        callback_call(:output, "\e[#{@y};#{@x}R", 0)
      elsif num == 5                       # DSR - reply ESC [ 0 n
        callback_call(:output, "\e[0n", 0)
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
      callback_call(:rowchange, @y, 0)
    end

    def _code_ED(num = 0)                  # erase display
      attr = DEFAULT_ATTR_PACKED

      # Wipe-cursor-to-end is the same as clear-whole-screen if cursor at top left
      #
      num = 2 if (num == 0) && (@x == 1) && (@y == 1)

      if num == 0                          # 0 = cursor to end
        @scrt[@y] = @scrt[@y][0, @x - 1] + ("\0" * (@cols + 1 - @x))
        @scra[@y] = @scra[@y][0, 2 * (@x - 1)] + (attr * (cols + 1 - @x))
        callback_call(:rowchange, @y, 0)

        row = @y + 1
        while row <= @rows
          @scrt[row] = "\0" * @cols
          @scra[row] = attr * @cols
          callback_call(:rowchange, row, 0)
          row += 1
        end
      elsif num == 1                       # 1 = start to cursor
        row = 1
        while row < @y
          @scrt[row] = "\0" * @cols
          @scra[row] = attr * @cols
          callback_call(:rowchange, row, 0)
          row += 1
        end

        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = (attr * @x) + @scra[@y][2 * @x .. -1]
        callback_call(:rowchange, @y, 0)
      else                                 # 2 = whole display
        callback_call(:clear, 0, 0)
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
        callback_call(:rowchange, @y, 0)
      elsif num == 1                      # 1 = start of line to cursor
        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = (attr * @x) + @scra[@y][(2 * @x) .. -1]
        callback_call(:rowchange, @y, 0)
      else                                 # 2 = whole line
        @scrt[@y] = "\0" * @cols
        @scra[@y] = attr * @cols
        callback_call(:rowchange, @y, 0)
      end
    end

    def _code_LF                          # line feed
      _code_CR if @opts[:lftocrlf]

      callback_call(:rowchange, @y, 0)
      _move_down
    end

    def _code_NEL                         # newline
      _code_CR                            # cursor always to start
      _code_LF                            # standard line feed
    end

    def _code_HT                          # horizontal tab to next tab stop
      if @opts[:linewrap] && @x >= @cols
        callback_call(:rowchange, @y, 0)
        @x = 1
        _move_down
      end

      newx = @x + 1
      while newx < @cols && !@tabstops[newx]
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
      @tabstops[@x] = true
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

      callback_call(:rowchange, @y, 0)
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
        callback_call(:rowchange, row, 0)

        row -= 1
      end

      row = @y
      while (row <= scrb) && (row < (@y + lines))
        @scrt[row] = "\000" * @cols
        @scra[row] = attr * @cols
        callback_call(:rowchange, row, 0)
        row += 1
      end
    end


    def _code_RIS                         # reset
      reset
    end

    def _toggle_mode(mode, flag)         # set/reset modes
      # Most modes stay in Fixnum form.  These are in "?1" form.  Let's make
      # sure no caller gets confused.
      unless mode.is_a?(String)
        fail ArgumentError, "mode must be in string form"
      end

      name = MODE_SEQ[modestr]
      func = METHOD_MAP[name] if name

      if func.nil?
        callback_call(:unknown, :mode, name, modestr, flag)
      else
        send(func, flag)
      end
    end

    # Takes an array of modes and an array of priv_flags, and turns them
    # back into a canonical string.  E.g.,
    #   modes: [1, 2, 3]
    #   priv_flags: [false, true, false]
    # -> ["1", "?2", "3"]
    def build_canonical_mode_names(modes, priv_flags)
      if modes.size != priv_flags.size
        fail ArgumentError, "modes and priv_flags must be same length"
      end
      modes.map.with_index do |m, f|
        "#{f ? '?' : ''}#{m}"
      end
    end

    def _code_RM(*modes, priv_flags:)        # reset mode
      modes = build_canonical_mode_names(modes, priv_flags)
      modes.each do |mode|
        _toggle_mode(mode, false)
      end
    end

    def _code_SM(*modes, priv_flags:)          # set mode
      modes = build_canonical_mode_names(modes, priv_flags)
      modes.each do |mode|
        _toggle_mode(mode, true)
      end
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

    def _code_SRM(val)
      @echo = val
      callback_call(:echochange, @echo)
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
        callback_call(:rowchange, @y, 0)
      end

      @x = @y = 1
    end

    def _code_DECSC                       # save state
      @decsc.push([@x, @y, @attr, @ti, @ic, @cursor])
    end

    def _code_DECRC                       # restore most recently saved state
      return if @decsc.empty?
      @x, @y, @attr, @ti, @ic, @cursor = @decsc.pop
    end

    def _code_CUPSV                       # save cursor position
      @cupsv.push([@x, @y])
    end

    def _code_CUPRS                       # restore cursor position
      return if @cupsv.empty?
      @x, @y = @cupsv.pop
    end

    def _code_XON                         # resume character processing
      @xon = true
    end

    def _code_XOFF                        # stop character processing
      return if @opts[:ignorexoff]
      @xon = false
    end
  end
end
