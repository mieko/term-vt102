# Based on Joshua Haberman's "VTParse" table generator, which was released into
# the public domain

module Term

  class DECParser
    attr_accessor :callback

    def initialize(&callback)
      @callback =callback

      @state = :GROUND
      @buf = []
      @ignore_flagged = false
      @params = []
      @string_type = nil

      build_state_table!
    end

    def parse(data)
      data.each_byte do |byte|
        ch = byte.ord
        change = @state_table[:ANYWHERE][ch]
        change ||= @state_table[@state][ch]
        if change
          do_state_change(change, ch)
        end
      end
    end

    private

    MAX_INTERMEDIATE_CHARS = 10

    class StateTransition
      attr_accessor :to_state
      def initialize(to_state)
        @to_state = to_state
      end
    end


    def do_action(action, ch)
      case action
        when :ignore
          # nothing

        when :str_type
          # These work in either context, :ANYWHERE or :ESCAPE
          @string_type = {
            0x58 => :sos,
            0x5e => :privacy,
            0x5f => :apc,

            0x98 => :sos,
            0x9e => :privacy,
            0x9f => :apc
          }[ch]

        when :str_start, :str_put, :str_end
          callback.call(action, @string_type, ch)

        when :esc_dispatch
          callback.call(action, @buf + [ch])

        when :csi_dispatch
          callback.call(action, ch, *@params)

        when :print
          callback.call(action, ch)

        when :execute
          callback.call(action, ch)

        when :osc_start, :osc_put, :osc_end
          callback.call(action, ch)

        when :print, :put, :hook, :unhook
          callback.call(action, ch)

        when :collect
          if @buf.size == MAX_INTERMEDIATE_CHARS
            @ignore_flagged = true
          else
            @buf.push(ch)
          end

        when :param
          if ch == '?'.ord
            @params.push([false, 0]) if @params.empty?
            @params[-1][0] = true
          elsif ch == ';'.ord
            @params.push([false, 0])
          else
            @params.push([false, 0]) if @params.empty?
            @params[-1][1] *= 10
            @params[-1][1] += (ch - '0'.ord)
          end

        when :clear
          @buf = []
          @params = []
          @ignore_flagged = false
        else
          fail RuntimeError, "internal error, unknown action #{action}"
      end
    end

    def do_state_change(change, ch)
      new_state = change.find {|v| v.is_a?(StateTransition) }
      new_state = new_state.to_state if new_state

      action = change.find {|v| v.is_a?(Symbol) }

      if new_state
        exit_action = if @state_table[@state]
          @state_table[@state].on_exit
        end

        entry_action = if @state_table[new_state]
          @state_table[new_state].on_entry
        end

        do_action(exit_action, 0) if exit_action
        do_action(action, ch) if action
        do_action(entry_action, 0) if entry_action
        @state = new_state
      else
        do_action(action, ch)
      end
    end

    def transition_to(state)
      StateTransition.new(state)
    end

    def build_state_table!
      states = {}
      states[:ANYWHERE] = {
        0x18       => [:execute, transition_to(:GROUND)],
        0x1a       => [:execute, transition_to(:GROUND)],
        0x80..0x8f => [:execute, transition_to(:GROUND)],
        0x91..0x97 => [:execute, transition_to(:GROUND)],
        0x99       => [:execute, transition_to(:GROUND)],
        0x9a       => [:execute, transition_to(:GROUND)],
        0x9c       => [:execute, transition_to(:GROUND)],
        0x1b       => transition_to(:ESCAPE),
        0x98       => [:str_type, transition_to(:SOS_PM_APC_STRING)],
        0x9e       => [:str_type, transition_to(:SOS_PM_APC_STRING)],
        0x9f       => [:str_type, transition_to(:SOS_PM_APC_STRING)],
        0x90       => transition_to(:DCS_ENTRY),
        0x9d       => transition_to(:OSC_STRING),
        0x9b       => transition_to(:CSI_ENTRY)
      }

      states[:GROUND] = {
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x20..0x7f => :print,
        0x80..0x8f => :execute,
        0x91..0x9a => :execute,
        0x9c       => :execute
      }

      states[:ESCAPE] = {
        :on_entry  => :clear,
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x7f       => :ignore,
        0x20..0x2f => [:collect, transition_to(:ESCAPE_INTERMEDIATE)],
        0x30..0x4f => [:esc_dispatch, transition_to(:GROUND)],
        0x51..0x57 => [:esc_dispatch, transition_to(:GROUND)],
        0x59       => [:esc_dispatch, transition_to(:GROUND)],
        0x5a       => [:esc_dispatch, transition_to(:GROUND)],
        0x5c       => [:esc_dispatch, transition_to(:GROUND)],

        0x60..0x7e => [:esc_dispatch, transition_to(:GROUND)],
        0x5b       => transition_to(:CSI_ENTRY),
        0x5d       => transition_to(:OSC_STRING),
        0x50       => transition_to(:DCS_ENTRY),
        0x58       => [:str_type, transition_to(:SOS_PM_APC_STRING)],
        0x5e       => [:str_type, transition_to(:SOS_PM_APC_STRING)],
        0x5f       => [:str_type, transition_to(:SOS_PM_APC_STRING)]
      }

      states[:ESCAPE_INTERMEDIATE] = {
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x20..0x2f => :collect,
        0x7f       => :ignore,
        0x30..0x7e => [:esc_dispatch, transition_to(:GROUND)]
      }

      states[:CSI_ENTRY] = {
        :on_entry  => :clear,
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x7f       => :ignore,
        0x20..0x2f => [:collect, transition_to(:CSI_INTERMEDIATE)],
        0x3a       => transition_to(:CSI_IGNORE),
        0x30..0x39 => [:param, transition_to(:CSI_PARAM)],
        0x3b       => [:param, transition_to(:CSI_PARAM)],
        0x3f       => [:param, transition_to(:CSI_PARAM)],
        0x3c..0x3e => [:collect, transition_to(:CSI_PARAM)],
        0x40..0x7e => [:csi_dispatch, transition_to(:GROUND)]
      }

      states[:CSI_IGNORE] = {
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x20..0x3f => :ignore,
        0x7f       => :ignore,
        0x40..0x7e => transition_to(:GROUND)
      }

      states[:CSI_PARAM] = {
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x30..0x39 => :param,
        0x3b       => :param,
        0x3f       => :param,
        0x7f       => :ignore,
        0x3a       => transition_to(:CSI_IGNORE),
        0x3c..0x3e => transition_to(:CSI_IGNORE),
        0x20..0x2f => [:collect, transition_to(:CSI_INTERMEDIATE)],
        0x40..0x7e => [:csi_dispatch, transition_to(:GROUND)]
      }

      states[:CSI_INTERMEDIATE] = {
        0x00..0x17 => :execute,
        0x19       => :execute,
        0x1c..0x1f => :execute,
        0x20..0x2f => :collect,
        0x7f       => :ignore,
        0x30..0x3f => transition_to(:CSI_IGNORE),
        0x40..0x7e => [:csi_dispatch, transition_to(:GROUND)]
      }

      states[:DCS_ENTRY] = {
        :on_entry  => :clear,
        0x00..0x17 => :ignore,
        0x19       => :ignore,
        0x1c..0x1f => :ignore,
        0x7f       => :ignore,
        0x3a       => transition_to(:DCS_IGNORE),
        0x20..0x2f => [:collect, transition_to(:DCS_INTERMEDIATE)],
        0x30..0x39 => [:param, transition_to(:DCS_PARAM)],
        0x3b       => [:param, transition_to(:DCS_PARAM)],
        0x3c..0x3f => [:collect, transition_to(:DCS_PARAM)],
        0x40..0x7e => [transition_to(:DCS_PASSTHROUGH)]
      }

      states[:DCS_INTERMEDIATE] = {
        0x00..0x17 => :ignore,
        0x19       => :ignore,
        0x1c..0x1f => :ignore,
        0x20..0x2f => :collect,
        0x7f       => :ignore,
        0x30..0x3f => transition_to(:DCS_IGNORE),
        0x40..0x7e => transition_to(:DCS_PASSTHROUGH)
      }

      states[:DCS_IGNORE] = {
        0x00..0x17 => :ignore,
        0x19       => :ignore,
        0x1c..0x1f => :ignore,
        0x20..0x7f => :ignore,
        0x9c       => transition_to(:GROUND)
      }

      states[:DCS_PARAM] = {
        0x00..0x17 => :ignore,
        0x19       => :ignore,
        0x1c..0x1f => :ignore,
        0x30..0x39 => :param,
        0x3b       => :param,
        0x7f       => :ignore,
        0x3a       => transition_to(:DCS_IGNORE),
        0x3c..0x3f => transition_to(:DCS_IGNORE),
        0x20..0x2f => [:collect, transition_to(:DCS_INTERMEDIATE)],
        0x40..0x7e => transition_to(:DCS_PASSTHROUGH)
      }

      states[:DCS_PASSTHROUGH] = {
        :on_entry  => :hook,
        0x00..0x17 => :put,
        0x19       => :put,
        0x1c..0x1f => :put,
        0x20..0x7e => :put,
        0x7f       => :ignore,
        0x9c       => transition_to(:GROUND),
        :on_exit   => :unhook
      }

      states[:OSC_STRING] = {
        :on_entry  => :osc_start,
        0x00..0x17 => :ignore,
        0x19       => :ignore,
        0x1c..0x1f => :ignore,
        0x20..0x7f => :osc_put,
        0x9c       => transition_to(:GROUND),
        :on_exit   => :osc_end
      }

      states[:SOS_PM_APC_STRING] = {
        :on_entry  => :str_start,
        0x00..0x17 => :str_put,
        0x19       => :str_put,
        0x1c..0x1f => :str_put,
        0x20..0x7f => :str_put,
        0x9c       => transition_to(:GROUND),
        :on_exit   => :str_end
      }

      @state_table = {}

      states.each do |state, transitions|
        @state_table[state] = expanded_state(transitions)
      end
    end

    # We take the shorthand notation, expand ranges on the left hand side, and
    # make sure the right hand side is an array.  We're left with an array that
    # can be indexed by an int between 0...255, get nil for no action, and get
    # an array of actions otherwise
    def expanded_state(state)
      result = []

      result.define_singleton_method(:on_entry) do
        state[:on_entry]
      end

      result.define_singleton_method(:on_exit) do
        state[:on_exit]
      end

      state.each do |k, v|
        rhs = Array(v)
        case k
        when Fixnum
          fail ArgumentError, sprintf("0x%x already specified", k) if result[k]
          result[k] = rhs
        when Range
          k.each do |i|
            fail ArgumentError, sprintf("0x%x already specified", i) if result[i]
            result[i] = rhs
          end
        when :on_entry, :on_exit
          # nothing: these are allowed.
        else
          fail ArgumentError, "found unknown key `#{k}' in state definition."
        end
      end
      result
    end
  end
end
