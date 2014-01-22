#!/usr/bin/env ruby

# This example just pulls a cool little tmux trick.
#
# Steps:
#   1. Start a tmux session
#   2. Make sure you're not doing anything important
#   3. Run this file
#   4. Watch either (or both) terminals
#
# This program creates a pty, and connects to it as the VT102.
# It then executes "tmux attach", and prints a ghost to the screen.
#
# The emulator will stay attached and refresh its screen every
# half second until you ^C it out of there.
#
# For a moment there, you're gonna have a terminal emulator (VT102) in a
# terminal emulator (tmux) in a terminal emulator (xterm, Konsole,
# Terminal.app, whatever).  Let that sink in, dawg.

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

# Unix-y enough require list for you?
require 'term/vt102'
require 'pty'
require 'io/console'

# Prints the entire VT102 screen to an IO
def dump(vt, to: $stderr)
  to.puts " ." + ('-' * (vt.cols)) + "."
  (1 .. vt.rows).each do |row|
    to.puts " |#{vt.row_plaintext(row)}|"
  end
  to.puts " '" + ('-' * (vt.cols)) + "'"
end

# Does the cool ghost thing.
def spooky(to:)
  @ghost ||= DATA.read
  @ghost.each_line do |line|
    to.puts "\# #{line}"
    sleep 0.2
  end
end

vt = Term::VT102.new
rd, wr, pid = PTY.spawn("tmux attach")

loop do
  s = rd.readpartial(1024)
  if s && !s.empty?
    vt.process(s)
    dump(vt, to: $stderr)

    unless defined?(@greeting)
      @greeting = true
      spooky(to: wr)
    end
  end

  sleep 0.5
end

__END__
               ___
             _/ ..\
            ( \  0/__
             \    \__)
             /     \
       jgs  /      _\
           `"""""``
BOO FROM TEH GHOST IN TEH MACHINE
