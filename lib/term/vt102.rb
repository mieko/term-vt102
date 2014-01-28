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
require 'term/vt102/events'

module Term
  class VT102
    include Term::Events
    events :bell,         # bell character received
           :goto,         # cursor moved
           :clear,        # screen cleared
           :output,       # data to be sent back to originator
           :rowchange,    # screen row changed
           :echochange,   # "echo" has been enabled or disabled
           :scroll_down,  # text about to move up (par=top row)
           :scroll_up,    # text about to move down (par=bott.)
           :unknown,      # unknown character / sequence
           :string,       # string received
           :icon_name,    # xterm icon name changed
           :window_name,  # xterm window title changed
           :mode,         # mode changed
           :linefeed,     # line feed about to be processed
           :log           # output log

    attr_reader :x, :y
    attr_reader :cols, :rows
    attr_reader :window_name, :icon_name

    def size
      [cols, rows]
    end

    attr_accessor :ignore_xoff
    attr_accessor :lf_to_crlf
    attr_accessor :line_wrap

    def initialize(cols: 80, rows: 24)
      @parser = Term::DECParser.new(&method(:cb_dispatch))
      @cols, @rows = (cols > 0 ? cols : 80),
                     (rows > 0 ? rows : 24)

      # Local options
      @lf_to_crlf  = false
      @ignore_xoff = true
      @line_wrap   = false

      reset!
    end

    # Return the current cursor visibity state
    def cursor?
      @cursor
    end

    # Return the current terminal status.
    def status
      [@x, @y, @attr, @window_name, @icon_name]
    end

    def process(string)
      @parser.parse(string.encode('ASCII-8BIT'))
    end

    def reset!
      @x = 1                               # default X position: 1
      @y = 1                               # default Y position: 1

      @attr = DEFAULT_ATTR_PACKED

      @window_name = ''                    # default: blank window title
      @icon_name = ''                      # default: blank icon title

      @srt = 1                             # scrolling region top: row 1
      @srb = @rows                         # scrolling region bottom

      @scrt = []                           # blank screen text
      @scra = []                           # blank screen attributes

      (1 .. @rows).each do |i|
        @scrt[i] = "\0" * @cols            # set text to NUL
        @scra[i] = [@attr] * @cols         # set attributes to default
      end

      @tabstops = []
      (1...@cols).step(8) do |i|
        @tabstops[i] = true
      end
      @echo   = true

      @xon    = true
      @cursor = true
      @decsc  = []
      @cupsv  = []
      @lnm    = false
      @decom  = false
      @decawm = false
    end


    private
    public

    # Returns true if the command (from the parser) would enable XON
    def xon_command?(command, *args)
      return (command == :execute && args[0] == 17)
    end

    # This is the callback we get from the parser
    def cb_dispatch(command, *args)
      if @xon || xon_command?(command, *args)
        send("cb_#{command}", *args)
      end
    end

    # control sequence ctl (Fixnum) received
    def cb_execute(ctl)
      handler = self.class.ctl_callable(self, ctl.chr)
      emit(:log, :command, ctl.chr)
      return handler.call if handler
      emit(:unknown, :command, ctl.chr)
    end

    # escape sequence esc_code (Fixnum) received
    def cb_esc_dispatch(esc_code)
      esc_string = esc_code.map(&:chr).join
      handler = self.class.esc_callable(self, esc_string)
      emit(:log, :esc, esc_string)
      return handler.call if handler
      emit(:unknown, :esc, esc_string)
    end

    # CSI code csi_code (Fixnum) received.  params are [Boolean, Fixnum] pairs,
    # which represent [private?, code]
    def cb_csi_dispatch(csi_code, *params)
      # params is a set of [private?, code] pairs
      handler = self.class.csi_callable(self, csi_code.chr)

      # Regular params stay Fixnum, Private codes turn to "\?[0-9]+" strings.
      # This is because most params should be integers, and the handlers
      # that work on private modes expect them.  They're typically identifiers
      # rather than coordinates.
      params = params.map do |priv, code|
        priv ? "?#{code}" : code
      end

      emit(:log, :csi, csi_code, params)
      return handler.call(*params) if handler
      emit(:unknown, :csi, csi_code, params)
    end

    def cb_print(ch)
      ch = ch.chr
      if @x == @cols + 1 && @decawm
        _move_down
        @x = 1
      end

      @scrt[@y][@x-1] = ch
      @scra[@y][@x-1] = @attr

      @x += 1
      @x = clamp_x(@x)
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
          emit(:icon_name, params[0])
          emit(:window_name, params[0])
        when '1'
          emit(:icon_name, params[0])
        when '2'
          emit(:window_name, params[0])
        else
          emit(:unknown, :osc, code, params)
      end
    end

    def cb_str_start(string_type, ch)
      @str_buf = ''
    end

    def cb_str_put(string_type, ch)
      @str_buf << ch.chr
    end

    def cb_str_end(string_type, ch)
      emit(:string, string_type, @str_buf)
    end


    class << self
      # Generates the code to give us "on_esc", "esc_callable", etc.
      [:ctl, :esc, :csi, :mode_set].each do |sym|
        # Accessor, e.g., ctl_seq = {}
        define_method("#{sym}_seq") do
          r = instance_variable_get("@#{sym}_seq")
          r ||= instance_variable_set("@#{sym}_seq", {})
          r
        end

        # defines, e.g., on_esc(code, :action, *params)
        define_method("on_#{sym}") do |code, *params, **kw, &block|
          r = send("#{sym}_seq")
          action = block.nil? ? params.shift : block
          r[code] = [action, params, kw]
        end

        define_method("#{sym}_callable") do |instance, lookup|
          record = send("#{sym}_seq")[lookup]
          return nil if record.nil?

          action, params, kw = *record
          if action.is_a?(Symbol)
            return nil unless instance.respond_to?(action)
            action = instance.method(action)
          end

          return ->(*iargs, **ikw, &ib) do
            pass_args = params + iargs
            pass_kw = kw.merge(ikw)
            if !pass_kw.empty?
              instance.instance_exec(*pass_args, **kw, &action)
            else
              instance.instance_exec(*pass_args, &action)
            end
          end
        end
      end
    end

    # ANSI control codes
    on_ctl "\000", :ignore
    on_ctl "\005", :_code_enq
    on_ctl "\007", :_code_bel
    on_ctl "\010", :_code_bs
    on_ctl "\011", :_code_ht
    on_ctl "\012", :_code_lf
    on_ctl "\013", :_code_lf
    on_ctl "\014", :_code_lf
    on_ctl "\015", :_code_cr
    on_ctl "\016", :_code_so
    on_ctl "\017", :_code_si
    on_ctl "\021", :_code_xon
    on_ctl "\023", :_code_xoff
    on_ctl "\177", :ignore

    # Escape codes
    on_esc  'c', :_code_ris
    on_esc  'D', :_code_ind
    on_esc  'E', :_code_nel
    on_esc  'H', :_code_hts
    on_esc  'M', :_code_ri
    on_esc  'N', :_code_ss2
    on_esc  'O', :_code_ss3
    on_esc  'P', :_code_dcs
    on_esc  'Z', :_code_decid
    on_esc  '7', :_code_decsc
    on_esc  '8', :_code_decrc
    on_esc '[[', :ignore
    on_esc '\\', :ignore
    on_esc '%@', :set_charset, 'iso646/8859-1'
    on_esc '%G', :set_charset, 'utf-8'
    on_esc '%8', :set_charset, 'utf-8'
    on_esc '#8', :_code_decaln
    on_esc '(8', :set_charset, 'iso646/8859-1', :g0
    on_esc '(0', :set_charset, 'vt100-graphics', :g0
    on_esc '(U', :set_charset, 'null', :g0
    on_esc '(K', :set_charset, 'user', :g0
    on_esc '(B', :set_charset, 'ascii', :g0
    on_esc ')8', :set_charset, 'iso646/8859-1', :g1
    on_esc ')0', :set_charset, 'vt100-graphics', :g1
    on_esc ')U', :set_charset, 'null', :g1
    on_esc ')K', :set_charset, 'user', :g1
    on_esc ')B', :set_charset, 'ascii', :g1
    on_esc '*8', :set_charset, 'iso646/8859-1', :g2
    on_esc '*0', :set_charset, 'vt100-graphics', :g2
    on_esc '*U', :set_charset, 'null', :g2
    on_esc '*K', :set_charset, 'user', :g2
    on_esc '+8', :set_charset, 'iso646/8859-1', :g3
    on_esc '+0', :set_charset, 'vt100-graphics', :g3
    on_esc '+U', :set_charset, 'null', :g3
    on_esc '+K', :set_charset, 'user', :g3
    on_esc  '>', :DECPNM
    on_esc  '=', :DECPAM
    on_esc  'N', :SS2
    on_esc  'O', :SS3
    on_esc  'n', :invoke_charset, :g2
    on_esc  'o', :invoke_charset, :g3
    on_esc  '|', :invoke_charset, :g3, as: :gr
    on_esc  '}', :invoke_charset, :g2, as: :gr
    on_esc  '~', :invoke_charset, :g1, as: :gr
    on_esc  'g', :_code_bel

    # CSI escape sequences
    on_csi '[',  :ignore
    on_csi '@',  :_code_ich
    on_csi 'A',  :_code_cuu
    on_csi 'B',  :_code_cud
    on_csi 'C',  :_code_cuf
    on_csi 'D',  :_code_cub
    on_csi 'E',  :_code_cnl
    on_csi 'F',  :_code_cpl
    on_csi 'G',  :_code_cha
    on_csi 'H',  :_code_cup
    on_csi 'I',  :_code_cht
    on_csi 'J',  :_code_ed
    on_csi 'K',  :_code_el
    on_csi 'L',  :_code_il
    on_csi 'M',  :_code_dl
    on_csi 'P',  :_code_dch
    on_csi 'W',  :_code_decst8c # ?5
    on_csi 'X',  :_code_ech
    on_csi 'Z',  :_code_cbt
    on_csi 'a',  :_code_hpr
    on_csi 'c',  :_code_da
    on_csi 'd',  :_code_vpa
    on_csi 'e',  :_code_vpr
    on_csi 'f',  :_code_hvp
    on_csi 'g',  :_code_tbc
    on_csi 'h',  :_code_sm
    on_csi 'l',  :_code_rm
    on_csi 'm',  :_code_sgr
    on_csi 'n',  :_code_dsr
    on_csi 'q',  :ignore
    on_csi 'r',  :_code_decstbm
    on_csi 's',  :_code_cupsv
    on_csi 'u',  :_code_cuprs
    on_csi '`',  :_code_hpa

    # Modesetting
    on_mode_set '0',   :ignore        # Error (Ignored)
    on_mode_set '1',   :ignore        # guarded-area transfer mode (ignored)
    on_mode_set '2',   :ignore        # keyboard action mode (always reset)
    on_mode_set '3',   :ignore        # control representation mode (always reset)
    on_mode_set '4',   :ignore        # insertion/replacement mode (always reset)
    on_mode_set '5',   :ignore        # status-reporting transfer mode
    on_mode_set '6',   :ignore        # erasure mode (always set)
    on_mode_set '7',   :ignore        # vertical editing mode (ignored)
    on_mode_set '10',  :ignore        # horizontal editing mode
    on_mode_set '11',  :ignore        # positioning unit mode
    on_mode_set '12',  :_code_srm     # send/receive mode (echo on/off)
    on_mode_set '13',  :ignore        # format effector action mode
    on_mode_set '14',  :ignore        # format effector transfer mode
    on_mode_set '15',  :ignore        # multiple area transfer mode
    on_mode_set '16',  :ignore        # transfer termination mode
    on_mode_set '17',  :ignore        # selected area transfer mode
    on_mode_set '18',  :ignore        # tabulation stop mode
    on_mode_set '19',  :ignore        # editing boundary mode
    on_mode_set '20',  :mode_lmn      # Line Feed / New Line Mode
    on_mode_set '?0',  :ignore        # Error (Ignored)
    on_mode_set '?1',  :ignore        # Cursorkeys application (set); Cursorkeys normal (reset)
    on_mode_set '?2',  :ignore        # ANSI (set); VT52 (reset)
    on_mode_set '?3',  :_mode_deccolm # 132 columns (set); 80 columns (reset)
    on_mode_set '?4',  :ignore        # Jump scroll (set); Smooth scroll (reset)
    on_mode_set '?5',  :ignore        # Reverse screen (set); Normal screen (reset)
    on_mode_set '?6',  :_mode_decom   # Sets relative coordinates (set); Sets absolute coordinates (reset)
    on_mode_set '?7',  :_mode_decawm  # Auto Wrap
    on_mode_set '?8',  :ignore        # Auto Repeat
    on_mode_set '?9',  :ignore        # Interlace
    on_mode_set '?18', :ignore        # Send FF to printer after print screen (set); No char after PS (reset)
    on_mode_set '?19', :ignore        # Print screen: prints full screen (set); prints scroll region (reset)
    on_mode_set '?25', :ignore        # Cursor on (set); Cursor off (reset)


    def set_charset(charset_name, target = nil)
      # We don't know how to do this yet.
    end

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
      num
    end

    def attr_pack(*args)
      self.class.attr_pack(*args)
    end

    # Return the unpacked version of a packed attribute.
    #
    def attr_unpack(num)
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

    # Return the attributes of the given row, or undef if out of range.
    #
    def row_attr(row, startcol = nil, endcol = nil)
      return nil unless (1 .. @rows).cover?(row)
      data = @scra[row].dup

      if startcol && endcol
        data = data[startcol - 1, (endcol - startcol) + 1]
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
      fail ArgumentError unless source.is_a?(Fixnum) && dest.is_a?(Fixnum)

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
        attr_next = row_attr[startcol - 1]
        text += sgr_change(attr_cur, attr_next) + char
        attr_cur = attr_next

        startcol += 1
      end

      attr_next = DEFAULT_ATTR_PACKED
      text += sgr_change(attr_cur, attr_next)

      text
    end

    def clamp_y(y)
      y = 1 if y < 1
      y = @rows if y > @rows
      y
    end

    def clamp_x(x)
      x = 1 if x < 1
      x = @cols + 1 if x > @cols + 1
      x
    end

    def clamp_xy(x, y)
      [clamp_x(x), clamp_y(y)]
    end

    def clamp_row_col(row, col)
      clamp_xy(col, row).reverse
    end

    # Scroll the scrolling region up such that the text in the scrolling region
    # moves down, by the given number of lines.
    #
    def _scroll_up(lines)
      return if lines < 1

      i = @srb
      while i >= @srt + lines
        @scrt[i] = @scrt[i - lines]
        @scra[i] = @scra[i - lines]
        i -= 1
      end

      attr = DEFAULT_ATTR_PACKED

      i = @srt
      while (i <= @srb) && (i < (@srt + lines))
        @scrt[i] = "\0" * @cols          # blank new lines
        @scra[i] = [attr] * @cols            # wipe attributes of new lines
        i += 1
      end

      emit(:scroll_up, @srb, lines)
    end

    # Scroll the scrolling region down such that the text in the scrolling region
    # moves up, by the given number of lines.
    #
    def _scroll_down(lines = 1)
      i = @srt
      while i <= (@srb - lines)
        @scrt[i] = @scrt[i + lines]
        @scra[i] = @scra[i + lines]
        i += 1
      end

      attr = DEFAULT_ATTR_PACKED

      i = @srb
      while (i >= @srt) && (i > (@srb - lines))
        @scrt[i] = "\0" * @cols      # blank new lines
        @scra[i] = [attr] * @cols        # wipe attributes of new lines
        i -= 1
      end

      emit(:scroll_down, @srt, lines)
    end

    # Move the cursor up the given number of lines, without triggering a GOTO
    # callback, taking scrolling into account.
    #
    def _move_up(num = 1)
      num = 1 if num < 1
      @y -= num
      return if @y >= @srt
      _scroll_up(@srt - @y)                # scroll
      @y = @srt
    end

    # Move the cursor down the given number of lines, without triggering a GOTO
    # callback, taking scrolling into account.
    #
    def _move_down(num = 1)
      num = 1 if num < 1
      @y += num
      return if @y <= @srb
      _scroll_down(@y - @srb)              # scroll
      @y = @srb
    end

    def _code_bel                          # beep
      emit(:bell)
    end

    def _code_bs                           # move left 1 character
      @x -= 1
      @x = 1 if @x < 1
    end

    def _code_decid
      _code_da
    end

    def _code_enq
      _code_da
    end

    def _code_cha(col = 1)                 # move to column in current row
      return if @x == col
      @x = col
      @x = clamp_x(@x)
      emit(:goto, @x, @y)
    end

    def _code_cnl(num = 1)                 # move cursor down and to column 1
      _move_down(num)
      @x = 1
      emit(:goto, @x, @y)
    end

    def _code_cpl(num = 1)                 # move cursor up and to column 1
      _move_up(num)
      @x = 1
      emit(:goto, @x, @y)
    end

    def _code_cr                           # carriage return
      @x = 1
      emit(:goto, @x, @y)
    end

    def _code_cub(num = 1)                 # move cursor left
      num = 1 if num == 0
      @x -= num
      @x = clamp_x(@x)
      emit(:goto, @x, @y)
    end

    def _code_cud(num = 1)                 # move cursor down
      num = 1 if num < 1
      @y += num
      @y = clamp_y(@y)
      emit(:goto, @x, @y)
    end

    def _code_cuf(num = 1)                 # move cursor right
      num = 1 if num == 0
      @x += num
      @x = clamp_x(@x)
      emit(:goto, @x, @y)
    end

    def _code_cup(row = 1, col = 1)        # move cursor to row, column
      row = 1 if row == 0
      col = 1 if col == 0
      @x, @y = col, decom_adjust(row)
      @x, @y = clamp_xy(@x, @y)

      emit(:goto, @x, @y)
    end

    def _code_hvp(row = 1, col = 1)
      row = 1 if row == 0
      col = 1 if col == 0
      @x, @y = col, row
      @x, @y = clamp_xy(x, y)
      emit(:goto, @x, @y)
    end

    def _code_ri                           # reverse line feed
      _move_up
      emit(:goto, @x, @y)
    end

    def _code_cuu(num = 1)                 # move cursor up
      num = 1 if num == 0
      @y -= num
      @y = clamp_y(@y)
      emit(:goto, @x, @y)
    end

    def _code_da(code = 0)                 # return ESC [ ? 6 c (VT102)
      emit(:output, "\e[?6c")
    end

    def _code_dch(num = 1)                 # delete characters on current line
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
      lsub, rsub = [], []
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[(@x - 1 + todel) .. -1]
      @scra[@y] = lsub + rsub + ([DEFAULT_ATTR_PACKED] * todel)

      emit(:rowchange, @y)
    end

    def _code_decstbm(top = 1, bottom = nil) # set scrolling region
      top = 1 if top < 1
      bottom ||= @rows
      bottom = @rows if bottom < top
      @srt, @srb = top, bottom
    end

    def _code_dectcem(cursor)              # Cursor on (set); Cursor off (reset)
      @cursor = (cursor == 1)
    end

    def _code_dl(lines = 1)                # delete lines
      lines = [lines, 1].max

      attr = DEFAULT_ATTR_PACKED

      scrb = @srb
      scrb = @rows if @y > @srb
      scrb = @srt - 1 if @y < @srt

      row = @y
      while row <= scrb - lines
        @scrt[row] = @scrt[row + lines]
        @scra[row] = @scra[row + lines]
        emit(:rowchange, row)
        row += 1
      end

      row = scrb
      while row > (scrb - lines) && row >= @y
        @scrt[row] = "\0" * @cols
        @scra[row] = [attr] * @cols
        emit(:rowchange, row)
        row -= 1
      end
    end

    def _code_cpr(num = 5)                 # device status report
      if num == 6                          # CPR - cursor position report
        emit(:output, "\e[#{@y};#{@x}R")
      elsif num == 5                       # DSR - reply ESC [ 0 n
        emit(:output, "\e[0n")
      end
    end

    def _code_ech(num = 1)                 # erase characters on current line
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
      lsub, rsub = [], []
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[(@x - 1 + todel) .. -1]

      @scra[@y] = lsub + ([DEFAULT_ATTR_PACKED] * todel) + rsub
      emit(:rowchange, @y)
    end

    def _code_ed(num = 0)                  # erase display
      attr = DEFAULT_ATTR_PACKED

      # Wipe-cursor-to-end is the same as clear-whole-screen if cursor at top left
      if (num == 0) && (@x == 1) && (@y == 1)
        num = 2
      end

      if num == 0  # 0 = cursor to end
        @scrt[@y] = @scrt[@y][0, @x - 1] + ("\0" * (@cols + 1 - @x))
        @scra[@y] = @scra[@y][0, @x - 1] + ([attr] * (@cols + 1 - @x))
        emit(:rowchange, @y)

        row = @y + 1
        while row <= @rows
          @scrt[row] = "\0" * @cols
          @scra[row] = [attr] * @cols
          emit(:rowchange, row)
          row += 1
        end
      elsif num == 1                       # 1 = start to cursor
        row = 1
        while row < @y
          @scrt[row] = "\0" * @cols
          @scra[row] = [attr] * @cols
          emit(:rowchange, row)
          row += 1
        end

        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = ([attr] * @x) + @scra[@y][@x .. -1]
        emit(:rowchange, @y)
      else                                 # 2 = whole display
        emit(:clear)
        row = 1
        while row <= rows
          @scrt[row] = "\0" * @cols
          @scra[row] = [attr] * @cols
          row += 1
        end
      end
    end

    def _code_el(num = 0)                  # erase line
      attr = DEFAULT_ATTR_PACKED

      if num == 0                         # 0 = cursor to end of line
        @scrt[@y] = @scrt[@y][0, @x - 1] + ("\0" * (@cols + 1 - @x))
        @scra[@y] = @scra[@y][0, @x - 1] + ([attr] * (@cols + 1 - @x))
        emit(:rowchange, @y)
      elsif num == 1                      # 1 = start of line to cursor
        @scrt[@y] = ("\0" * @x) + @scrt[@y][@x .. -1]
        @scra[@y] = ([attr] * @x) + @scra[@y][@x .. -1]
        emit(:rowchange, @y)
      else                                 # 2 = whole line
        @scrt[@y] = "\0" * @cols
        @scra[@y] = [attr] * @cols
        emit(:rowchange, @y)
      end
    end

    def _code_lf                          # line feed
      _code_cr if @lr_to_crlf || @lnm

      emit(:rowchange, @y)
      _move_down
    end

    def _code_nel                         # newline
      _code_cr                            # cursor always to start
      _code_lf                            # standard line feed
    end

    def _code_ind
      _move_down
    end

    def _code_ht                          # horizontal tab to next tab stop
      newx = @x + 1
      while newx < @cols && @tabstops[newx].nil?
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

    def _code_hts                         # set tab stop at current column
      @tabstops[@x] = true
    end

    def _code_tbc(num = 0)               # clear tab stop (CSI 3 g = clear all stops)
      if num == 3
        @tabstops = []
      elsif num == 0
        @tabstops[@x] = nil
      end
    end

    def _code_ich(num = 1)                # insert blank characters
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
      lsub, rsub = [], []
      lsub = line[0, @x - 1] if @x > 1
      rsub = line[@x - 1, width - toins]
      @scra[@y] = lsub + ([attr] * toins) + rsub

      emit(:rowchange, @y)
    end

    def _code_il(lines = 1)               # insert blank lines
      lines = [lines, 1].max

      attr = DEFAULT_ATTR_PACKED

      scrb = @srb
      scrb = @rows if @y > @srb
      scrb = @srt - 1 if @y < @srt

      row = scrb
      while row >= y + lines
        @scrt[row] = @scrt[row - lines]
        @scra[row] = @scra[row - lines]
        emit(:rowchange, row)

        row -= 1
      end

      row = @y
      while (row <= scrb) && (row < (@y + lines))
        @scrt[row] = "\000" * @cols
        @scra[row] = [attr] * @cols
        emit(:rowchange, row)
        row += 1
      end
    end


    def _code_ris                         # reset
      reset
    end

    def _mode_lnm(set)
      @lnm = set
    end

    def decom_adjust(y)
      if @decom
        @srt + (y-1)
      else
        y
      end
    end

    def _mode_decom(set)
      @decom = set
      @x = 1
      @y = decom_adjust(1)
    end

    def _mode_deccolm(set)
      @rows, @cols = set ? [24, 132] : [24, 80]
      @srt = 1
      @srb = @rows
      (1 .. @rows).each do |i|
        @scrt[i] = "\0" * (@cols + 1)          # set text to NUL
        @scra[i] = [@attr] * (@cols + 1)       # set attributes to default
      end
      @x = @y = 1
    end

    def _mode_decawm(set)
      @decawm = set
    end

    def _set_mode(mode, flag)         # set/reset modes
      handler = self.class.mode_set_callable(self, mode)
      emit(:log, :mode, mode, flag)
      return handler.call(flag) if handler
      emit(:unknown, :mode, mode, flag)
    end

    def _code_rm(*modes)        # reset mode
      modes.each do |mode|
        _set_mode(mode.to_s, false)
      end
    end

    def _code_sm(*modes)          # set mode
      modes.each do |mode|
        _set_mode(mode.to_s, true)
      end
    end

    def _code_sgr(*parms)                 # set graphic rendition
      fg, bg, bo, fa, st, ul, bl, rv = attr_unpack(@attr)

      parms = [0] if parms.empty?         # ESC [ m = ESC [ 0 m
      parms.each do |val|
        case val
          when 0;       fg, bg, bo, fa, st, ul, bl, rv = DEFAULT_ATTR  # reset
          when 1;       bo, fa = 1, 0           # bold ON
          when 2;       bo, fa = 0, 1           # faint ON
          when 4;       ul = 1                  # underline ON
          when 5;       bl = 1                  # blink ON
          when 7;       rv = 1                  # reverse video ON
          when 21..22;  bo, fa = 0, 0           # normal intensity
          when 24;      ul = 0                  # underline OFF
          when 25;      bl = 0                  # blink OFF
          when 27;      rv = 0                  # reverse video OFF
          when 30..37;  fg = val - 30           # set foreground colour
          when 38;      ul, fg = 1, 7           # underline on, default fg
          when 39;      ul, fg = 0, 7           # underline off, default fg
          when 40..47;  bg = val - 40           # set background colour
          when 49;      bg = 0                  # default background
        end
      end

      @attr = attr_pack(fg, bg, bo, fa, st, ul, bl, rv)
    end

    def _code_srm(val)
      @echo = val
      emit(:echochange, @echo)
    end

    def _code_vpa(row = 1)                # move to row (current column)
      return if @y == row

      @y = [row, 1].max
      @y = @rows if @y > @rows
    end

    def _code_decaln                      # fill screen with E's
      attr = DEFAULT_ATTR_PACKED

      (1 .. @rows).each do |row|
        @scrt[row] = 'E' * @cols
        @scra[row] = [attr] * @cols
        emit(:rowchange, @y)
      end

      @x = @y = 1
    end

    def _code_decsc                       # save state
      @decsc.push([@x, @y, @attr, @window_name, @icon_name, @cursor])
    end

    def _code_decrc                       # restore most recently saved state
      return if @decsc.empty?
      @x, @y, @attr, @window_name, @icon_name, @cursor = @decsc.pop
    end

    def _code_cupsv                       # save cursor position
      @cupsv.push([@x, @y])
    end

    def _code_cuprs                       # restore cursor position
      return if @cupsv.empty?
      @x, @y = @cupsv.pop
    end

    def _code_xon                         # resume character processing
      @xon = true
    end

    def _code_xoff                        # stop character processing
      return if @ignore_xoff
      @xon = false
    end

    def ignore(*)
    end

    def unimplemented(*args)
      warn "[unimplemented]: #{args.inspect}"
    end

  end
end
