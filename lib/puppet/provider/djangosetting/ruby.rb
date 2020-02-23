require 'puppet/util/execution'

Puppet::Type.type(:djangosetting).provide(:ruby) do
  # Without initvars commands won't work.
  initvars

  commands python: 'python'
  # https://docs.puppet.com/guides/provider_development.html
  def exists?
    lines
    if resource[:ensure].to_s == 'absent'
      @exists || @exists.nil?
    else
      @exists
    end
  end

  def create
    File.open(config, 'w') do |fh|
      fh.write(lines.join("\n"))
    end
  end

  def destroy
    File.open(config, 'w') do |fh|
      fh.write(lines.reject { |l| l.index("#{name}=") == 0 }.join("\n"))
    end
  end

  def config
    @config ||= resource[:config]
  end

  def lines
    @lines ||= get_lines
  end

  def line
    lines
    @line
  end

  def name
    @name ||= resource[:name]
  end

  def value
    @value ||= resource[:value]
  end

  # @lines - is array of lines from current file plus desired variable and value
  # @exists - flag which could have only values true, false or nil
  #           true - means variable exists and its value is desired
  #           false - means variable does not exists
  #           nil - means variable exists but with different value
  def get_lines # rubocop:disable Style/AccessorMethodName
    @exists = nil
    # if value is nil or empty - read file content
    if value.nil? || value.empty?
      content = pyrun(config)
      lines = content.split(%r{\n+})

      @line = lines.select { |l| l.index("#{name}=") == 0 }.last
      @exists = false if @line.nil?
    else
      content = pyrun(config, "#{name}=#{value}")
      lines = content.split(%r{\n+})

      if lines.length == 1
        @line = lines.first

        content = pyrun(config)
        lines2 = content.split(%r{\n+})

        # variable exists with desired value set
        lines = lines2 if lines2.include?(@line)

        @exists = if lines2.empty?
                    # variable is not existing if file empty
                    false
                  elsif lines2.length == 1
                    # if file of single line - this line is our variable
                    nil
                  else
                    true
                  end
      elsif lines.last.index("#{name}=") == 0
        @exists = false
        @line = lines.last
      end
    end

    lines
  end

  def pyrun(*args)
    pyparse = <<-'PYSCRIPT'
import os.path
import sys
import ast, _ast
import parser
def _astType(v, dq = False):
  if type(v) == _ast.Str:
    return "\"%s\"" % v.s if dq else "'%s'" % v.s
  elif type(v) == _ast.Name:
    return v.id
  elif type(v) == _ast.Dict:
    o = ','.join([':'.join(map(lambda x: _astType(x, dq), y)) for y in zip(v.keys, v.values)]) if len(v.keys) else ''
    return "{%s}" % o
  elif type(v) == _ast.Assign:
    return '='.join(map(lambda x: _astType(x, dq), [v.targets[0], v.value]))
  elif type(v) == _ast.List:
    o = ','.join(map(lambda x: _astType(x, dq), v.elts)) if len(v.elts) else ''
    return "[%s]" % o
  elif type(v) == _ast.Call:
    o = []
    if len(v.args):
      o += [ ','.join(map(lambda x: _astType(x, dq), v.args)) ]
    if v.starargs:
      o += [ '*' + _astType(v.starargs, dq) ]
    if len(v.keywords):
      o += [ ','.join(map(lambda x: _astType(x, dq), v.keywords)) ]
    if v.kwargs:
      o += [ '**' + _astType(v.kwargs, dq) ]
    return _astType(v.func) + "(%s)" % ','.join(o)
  elif type(v) == _ast.Num:
    return str(v.n)
  elif type(v) == _ast.Mod:
    return '%'
  elif type(v) == _ast.Mult:
    return '*'
  elif type(v) == _ast.Tuple:
    o = ','.join(map(lambda x: _astType(x, dq), v.elts)) if len(v.elts) else ''
    return "(%s)" % o
  elif type(v) == _ast.BinOp:
    return ' '.join(map(lambda x: _astType(x, True), [v.left, v.op, v.right]))
  elif type(v) == _ast.keyword:
    return v.arg + '=' + _astType(v.value, dq)
  elif type(v) == _ast.Import:
    return 'import ' + ','.join(map(lambda x: _astType(x, dq), v.names))
  elif type(v) == _ast.alias:
    o = v.name
    if v.asname:
      o += " as " + v.asname
    return o
  elif type(v) == _ast.ImportFrom:
    return "from %s import " % v.module + ','.join(map(lambda x: _astType(x, dq), v.names))
  elif type(v) == _ast.IfExp:
    return "%s if %s else %s" % (_astType(v.body, dq), _astType(v.test, dq), _astType(v.orelse, dq))
  else:
    return str([ v, v.__dict__ ])
config   = sys.argv[1] if len(sys.argv) > 1 else None
varcode = sys.argv[2] if len(sys.argv) > 2 else None
code = None
if config and os.path.isfile(config):
  with open(config) as f:
    code = f.read()
tree    = ast.parse(code)    if code    else None
vartree = ast.parse(varcode) if varcode else None
v = None
if vartree \
and len(vartree.body) == 1:
  for e in vartree.body:
    if type(e) == _ast.Assign:
      v = e
if tree:
  rawtree = [_astType(e) for e in tree.body]
  if type(v) == _ast.Assign:
    vraw = _astType(v)
    vcur = map(_astType, filter(lambda x: type(x) == _ast.Assign and x.targets[0].id == v.targets[0].id, tree.body))
    if vraw in vcur:
      print vraw
      sys.exit(0)
    else:
      rawtree = map(lambda x: vraw if x in vcur else x, rawtree)
      if vraw not in rawtree:
        rawtree += [vraw]
  for e in rawtree:
    print e
sys.exit(0)
    PYSCRIPT

    python(['-c', pyparse, *args].compact)
  end
end
