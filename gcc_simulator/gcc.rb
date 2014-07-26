
class Simulator

  class Data
    INT = 0
    CLOSURE = 1
    DUM = 2
    RET = 3
    STOP = 4
    def initialize(tag, value)
      @tag, @value = tag, value
    end
    def tag; @tag; end
  end

  class Frame
    def initialize()
  end

  DEBUG = false
  FATAL = true

  def initialize(filename, cin=$stdin, cout=$stdout, ext_out=$stderr)
    @cin, @cout, @ext_out = cin, cout, ext_out

    @reg_c = 0 # control register (program counter / instruction pointer)
    @reg_s = 0 # data stack register
    @reg_d = 0 # control stack register
    @reg_e = 0 # environment frame register

    @data_stack = []
    @ctrl_stack = []
    @envf_stack = []
    @heap = []

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

  def ireg(inst, n); Regexp.new([inst].concat(['([^\s]+)'] * n).join('\s+')); end

  def run
    @reg_c = 0
    loops = 0

    while loops < 3072000
      if line =~ ireg("ldc", 1)
        @reg_s = @data_stack.push(Data.new(DATA::INT, $1.to_i)).length
        @reg_c += 1
      elsif line =~ ireg("ld", 2)

      end
    end
  end

  def main
  end

end
