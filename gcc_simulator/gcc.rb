
class Simulator
  DEBUG = false
  FATAL = true

  def initialize(filename, cin=$stdin, cout=$stdout, ext_out=$stderr)
    @cin, @cout, @ext_out = cin, cout, ext_out
    @pc = 0
    @reg = Array.new(8, 0)
    @mem = Array.new(256, 0)
    @program = open(filename).read.split("\n")

    # delete comments
    @program = @program.map{|line|
      c = line.index(';')
      line = line.slice(0, c) if c
      line.strip
    }
  end

  def log(str); puts str if DEBUG; end
  def error(str); puts str if FATAL; end

  def run
  end

  def main
  end

end
