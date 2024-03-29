
require 'pp'

class Simulator
  DEBUG = false
  FATAL = true
  MOD = 256

  def initialize(filename, cin=$stdin, cout=$stdout, ext_out=$stderr)
    @cin, @cout, @ext_out = cin, cout, ext_out
    @pc = 0
    @reg = Array.new(8, 0)
    @mem = Array.new(256, 0)
    @program = open(filename).read.split("\n")

    # delete no operation lines
    @program = @program.map{|line|
      c = line.index(';')
      line = line.slice(0, c) if c
      line.strip
    }.reject {|item| item == ""}
  end

  def log(str); puts str if DEBUG; end
  def error(str); puts str if FATAL; end

  def extract_val(arg)
    if arg =~ /^\[([^\]]+)\]$/ # indirect
      r = $1
      if r =~ /^(\d+)$/
        return @mem[$1.to_i]
      elsif r == "pc"
        return @mem[@pc]
      elsif r =~ /^([a-h])$/
        return @mem[@reg[$1.ord - 'a'.ord]]
      end
    else
      if arg =~ /^(\d+)$/
        return $1.to_i
      elsif arg == "pc"
        return @pc
      elsif arg =~ /^([a-h])$/
        return @reg[$1.ord - 'a'.ord]
      end
    end
  end

  def binop(dest, src, func)
    dest_val = self.extract_val(dest)
    src_val = self.extract_val(src)

    ret = func.call(dest_val, src_val)

    if dest =~ /^\[([^\]]+)\]$/
      r = $1
      if r =~ /^(\d+)$/
        @mem[$1.to_i] = ret
      elsif r == "pc"
        @mem[@pc] = ret
      elsif r =~ /^([a-h])$/
        @mem[@reg[$1 - 'a']] = ret
      end
    else
      if dest =~ /^(\d+)$/
        error "Line #{@pc}: mov dest must not be a constant; #{dest}"
        return false
      elsif dest == "pc"
        @pc = ret
      elsif dest =~ /^([a-h])$/
        @reg[$1.ord - 'a'.ord] = ret
      end
    end
    return true
  end

  # inc or dec
  def unaop (dest, func)
    val = self.extract_val(dest)
    ret = func.call(val)

    if dest =~ /^\[([^\]]+)\]$/
      r = $1
      if r =~ /^(\d+)$/
        @mem[$1.to_i] = ret
      elsif r == "pc"
        @mem[@pc] = ret
      elsif r =~ /^([a-h])$/
        @mem[@reg[$1.ord - 'a'.ord]] = ret
      end
    else
      if dest =~ /^(\d+)$/
        error "Line #{@pc}: mov dest must not be a constant; #{dest}"
        return false
      elsif dest == "pc"
        error "Line #{@pc}: mov dest must not be a constant; #{dest}"
        return false
      elsif dest =~ /^([a-h])$/
        @reg[$1.ord - 'a'.ord] = ret
      end
    end
    return true
  end

  def run
    loops = 0

    @pc = 1
    while @pc < @program.length && loops < 1024

      pre_pc = @pc
      line = @program[@pc]

      if line =~ /^mov\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "mov #{$1},#{$2}"
        break if ! binop $1, $2, lambda {|a, b| b}
      elsif line =~ /^inc\s+([^\s]+)/i
        self.log "inc #{$1}"
        break if ! unaop $1, lambda {|a| (a + 1) % MOD}
      elsif line =~ /^dec\s+([^\s]+)/i
        self.log "dec #{$1}"
        break if ! unaop $1, lambda {|a| (a - 1) % MOD}
      elsif line =~ /^add\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "add"
        binop $1, $2, lambda {|a, b| (a + b) % MOD}
      elsif line =~ /^sub\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "sub"
        binop $1, $2, lambda {|a, b| (a - b) % MOD}
      elsif line =~ /^mul\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "mul"
        binop $1, $2, lambda {|a, b| (a * b) % MOD}
      elsif line =~ /^div\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "div"
        binop $1, $2, lambda {|a, b| (a / b) % MOD}
      elsif line =~ /^and\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "and"
        binop $1, $2, lambda {|a, b| (a & b) % MOD}
      elsif line =~ /^or\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "or"
        binop $1, $2, lambda {|a, b| (a | b) % MOD}
      elsif line =~ /^xor\s+([^\s]+)\s*,\s*([^\s]+)/i
        self.log "xor"
        binop $1, $2, lambda {|a, b| (a ^ b) % MOD}
      elsif line =~ /^jlt\s+([^\s]+)\s*,\s*([^\s]+)\s*,\s*([^\s]+)/i
        self.log "jlt"
        targ, x, y = $1.to_i, self.extract_val($2), self.extract_val($3)
        # $1 must be constant integer
        @pc = targ if x < y
      elsif line =~ /^jeq\s+([^\s]+)\s*,\s*([^\s]+)\s*,\s*([^\s]+)/i
        self.log "jeq"
        targ, x, y = $1.to_i, self.extract_val($2), self.extract_val($3)
        # $1 must be constant integer
        @pc = targ if x == y
      elsif line =~ /^jgt\s+([^\s]+)\s*,\s*([^\s]+)\s*,\s*([^\s]+)/i
        self.log "jgt"
        targ, x, y = $1.to_i, self.extract_val($2), self.extract_val($3)
        self.log "#{$2}, #{$3}, #{x}, #{y}"
        # $1 must be constant integer
        @pc = targ if x > y
      elsif line =~ /^int\s+([^\s]+)/i
        self.log "int #{$1}"
        svc = $1
        if svc == "0"
          @cout.puts "int 0 #{@reg[0]}"
          @cout.flush
        elsif svc == "1"
          @cout.puts "int 1"
          @cout.flush
          res = @cin.gets # such like "20 30"
          @reg[0], @reg[1] = res.strip.split(" ").map {|o| o.to_i}
        elsif svc == "2"
          @cout.puts "int 2"
          @cout.flush
          res = @cin.gets # such like "20 30"
          @reg[0], @reg[1] = res.strip.split(" ").map {|o| o.to_i}
        elsif svc == "3"
          @cout.puts "int 3"
          @cout.flush
          res = @cin.gets # such like "4"
          @reg[0] = res.strip.to_i
        elsif svc == "4"
          @cout.puts "int 4 #{@reg[0]}"
          @cout.flush
          res = @cin.gets
          @reg[0], @reg[1] = res.strip.split(" ").map {|o| o.to_i}
        elsif svc == "5"
          @cout.puts "int 5 #{@reg[0]}"
          @cout.flush
          res = @cin.gets
          @reg[0], @reg[1] = res.strip.split(" ").map {|o| o.to_i}
        elsif svc == "6"
          @cout.puts "int 6 #{@reg[0]}"
          @cout.flush
          res = @cin.gets
          @reg[0], @reg[1] = res.strip.split(" ").map {|o| o.to_i}
        elsif svc == "7"
          @cout.puts "int 7 #{@reg[0]} #{@reg[1]}"
          @cout.flush
          res = @cin.gets
          @reg[0] = res.strip.to_i
        elsif svc == "8"
          ext_out.puts "pc = #{@pc}"
          ext_out.flush
          8.times do |i|
            ext_out.puts "@reg[#{i}] = #{@reg[i]}"
            ext_out.flush
          end
        end

      elsif line =~ /^hlt/i
        self.log "hlt"
        @cout.puts "hlt"
        @cout.flush
        break
      else
        self.error "Line #{@pc}: No such a operation; #{line}"
      end

      # self.log "#{@pc}(#{loops}):"
      # self.dump
      # self.log ""

      loops += 1
      @pc += 1 if @pc == pre_pc
    end
  end

  def main
    while true
      start = @cin.gets
      break if start.strip == "game over"
      self.run
      self.dump
    end
  end

  def dump
    self.log "pc = #{@pc}"
    self.log @reg.join(',')
    self.log @mem.slice(0, 4).join(',')
  end
end

s = Simulator.new(ARGV[0])
s.main
