DELIMITER = /(\s|\))/


define = (expr, env) ->
    dvar = expr.cdr.car
    dval = expr.cdr.cdr.car.eval(env)
    frame = env.car
    vars = frame.car
    vals = frame.cdr.car
    while not vars.null?
        if vars.car.symbol == dvar.symbol
            vals.car = dval
            return
        vars = vars.cdr
        vals = vals.cdr
    frame.car = Cell(dvar, frame.car)
    frame.cdr.car = Cell(dval, frame.cdr.car)


lookup = (expr, env) ->
    while not env.null?
        frame = env.car
        vars = frame.car
        vals = frame.cdr.car
        while not vars.null?
            if vars.car.symbol == expr.symbol
                return vals.car
            vars = vars.cdr
            vals = vals.cdr
        env = env.cdr
    throw "unbound variable #{expr.write()}"


set = (expr, env) ->
    svar = expr.cdr.car
    sval = expr.cdr.cdr.car
    while not env.null?
        frame = env.car
        vars = frame.car
        vals = frame.cdr.car
        while not vars.null?
            if vars.car.symbol == svar.symbol
                vals.car = sval
                return
            vars = vars.cdr
            vals = vals.cdr
        env = env.cdr
    throw "unbound variable #{svar.write()}"


cond = (body, env) ->
    return Cell('#f') if body.null?
    condition = body.car.car
    condition = Cell('#t') if condition.symbol == 'else'
    consequence = body.car.cdr.car
    return consequence.eval(env) if condition.eval(env).symbol != '#f'
    return cond(body.cdr, env)


eval_operands = (operands, env) ->
    return List() if operands.null?
    return Cell(operands.car.eval(env),
                eval_operands(operands.cdr, env))


class Cell

    constructor: (args...) ->
        if args.length == 2
            [car, cdr] = args
            @car = if car.cell? then car else Cell(car)
            @cdr = if cdr.cell? then cdr else Cell(cdr)
            @pair = true
        else if args[0] is null
            @null = true
        else if typeof args[0] is 'number' or not isNaN(parseInt(args[0]))
            @number = parseInt(args[0])
            @atom = true
            @self_evaluating = true
        else if args[0] in ['#t', '#f']
            @symbol = args[0]
            @boolean = true
            @atom = true
            @self_evaluating = true
        else if typeof args[0] is 'string'
            @symbol = args[0]
            @atom = true
        else if typeof args[0] is 'function'
            @primitive = args[0]
        else if args[0].procedure?
            @procedure = args[0].procedure
            @env = args[0].env
        else if args[0].cell?
            return args[0]
        else
            console.log args[0]
        @cell = true
        return new Cell arguments... if this not instanceof Cell

    @_read_pair: (source) ->
        source = source.trim()
        if source[0] == ')'
            return [Cell(null), source[1..]]
        [car, rest] = @_read(source)
        rest = rest.trim()
        throw 'missing right paren' if rest == ''
        if rest[0] == '.'
            throw 'missing right paren' if rest[1..] == ''
            throw 'no delimiter after dot' if not DELIMITER.test rest[1]
            [cdr, rest] = @_read(rest[1..])
            throw 'missing right paren' if rest[0] != ')'
            return [Cell(car, cdr), rest[1..]]
        [cdr, rest] = @_read_pair(rest)
        return [Cell(car, cdr), rest]

    @_read: (source) ->
        """Read `String source` and return [Cell parsed, String rest]."""
        source = source.trim()
        char = source[0]
        rest = source[1..]
        if char == '('
            return @_read_pair(rest)
        else if char == "'"
            [quoted, rest] = @_read(rest)
            return [List('quote', quoted), rest]
        else
            [symbol, rest...] = source.split(DELIMITER)
            return [Cell(symbol), rest.join('')]

    @read: (source) ->
        @_read(source)[0]

    eval: (env=List()) ->
        expr = this
        if expr.self_evaluating?
            return expr
        else if expr.pair? and expr.car.symbol == 'quote'
            return expr.cdr.car
        else if expr.symbol?
            return lookup(expr, env)
        else if expr.pair? and expr.car.symbol == 'define'
            define(expr, env)
            return Cell('ok')
        else if expr.pair? and expr.car.symbol == 'set!'
            set(expr, env)
            return Cell('ok')
        else if expr.pair? and expr.car.symbol == 'cond'
            return cond(expr.cdr, env)
        else if expr.pair? and expr.car.symbol == 'env'
            return env
        #else if expr.pair? and expr.car.symbol == 'and'
            #return ...cond(expr.cdr, env)
        else if expr.pair? and expr.car.symbol == 'lambda'
            return Cell(procedure: expr, env: env)
        else if expr.pair?
            operator = expr.car.eval(env)
            args = eval_operands(expr.cdr, env)
            if operator.primitive?
                return Cell(operator.primitive(args))
            else if operator.procedure?
                para = operator.procedure.cdr.car
                body = operator.procedure.cdr.cdr.car
                env = Cell(List(para, args), operator.env)
                return body.eval(env)
        throw "eval error: #{expr.write()}"

    @evaluate__: (source) ->
        env = Cell.default_env()
        result = ''
        while source != ''
            [parsed, source] = Cell._read(source)
            evaled = parsed.eval(env)
            result += evaled.write() + '\n'
        return result

    @evaluate: (source) ->
        env = Cell.default_env()
        result = []
        line = 0
        while source != ''
            [parsed, rest] = Cell._read(source)
            line = source.replace(rest, '').match(/\n/g).length + line
            source = rest
            result.push line: line, result: parsed.eval(env).write()
        return result

    @default_env: ->
        env = @read('((() ()))')
        for name, func of @_primitives
            define(List('define', name, List('quote', func)), env)
        return env

    @_primitives:
        'null?': (args) -> if args.car.null? then '#t' else '#f'
        'atom?': (args) -> if args.car.atom? then '#t' else '#f'
        'eq?': (args) -> if args.car.is_eq args.cdr.car then '#t' else '#f'
        'cons': (args) -> Cell(args.car, args.cdr.car)
        'car': (args) -> args.car.car
        'cdr': (args) -> args.car.cdr
        'zero?': (args) -> if args.car.number == 0 then '#t' else '#f'
        'add1': (args) -> args.car.number + 1
        'sub1': (args) -> args.car.number - 1
        'number?': (args) -> if args.car.number? then '#t' else '#f'

    _write_pair: ->
        if @cdr.null?
            "#{@car.write()}"
        else if @cdr.pair?
            "#{@car.write()} #{@cdr._write_pair()}"
        else if @cdr.write?
            "#{@car.write()} . #{@cdr.write()}"
        else
            '#<wtf>'

    write: ->
        if @pair?
            "(#{@_write_pair()})"
        else if @symbol?
            @symbol
        else if @null?
            '()'
        else if @number?
            @number.toString()
        else if @primitive?
            '#<primitive>'
        else if @procedure?
            "<function #{@procedure.write()}>"
        else
            throw 'write error'

    is_eq: (other) ->
        law = 'eq? takes two non-numeric atoms'
        if @null? and other.null?
            true
        else if @symbol? and other.symbol?
            @symbol == other.symbol
        else
            throw law


List = (args...) ->
    if args.length == 0
        Cell(null)
    else
        Cell(args[0], List(args[1..]...))


provide =
    Cell: Cell
    List: List
    eval: Cell.evaluate


if module?
    module.exports = provide
else
    window.little = provide
