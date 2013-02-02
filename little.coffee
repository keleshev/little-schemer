print = -> console.log arguments...


DELIMITER = /(\s|\))/


define = (args, env) ->
    dvar = args.car
    dval = args.cdr.car
    frame = env.car
    vars = frame.car
    vals = frame.cdr.car
    while not vars.null?
        if vars.car.symbol == dvar.symbol
            vals.car = dval
            return 'ok'
        vars = vars.cdr
        vals = vals.cdr
    frame.car = Cell(dvar, frame.car)
    frame.cdr.car = Cell(dval, frame.cdr.car)
    return 'ok'


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


set = (args, env) ->
    svar = args.car
    sval = args.cdr.car
    while not env.null?
        frame = env.car
        vars = frame.car
        vals = frame.cdr.car
        while not vars.null?
            if vars.car.symbol == svar.symbol
                vals.car = sval
                return 'ok'
            vars = vars.cdr
            vals = vals.cdr
        env = env.cdr
    throw "unbound variable #{svar.write()}"


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
        else if args[0].special?
            @special = args[0].special
            @name = args[0].name
        else if args[0].primitive?
            @primitive = args[0].primitive
            @name = args[0].name
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

    eval_simple: (env) ->

    eval: (env=null) ->
        if not env?
            env = Cell.default_env()
        expr = this
        loop
            if expr.self_evaluating?
                return expr
            else if expr.symbol?
                return lookup(expr, env)
            else if expr.pair? and expr.car.symbol == 'cond'
                body = expr.cdr
                return Cell('#f') if body.null?
                condition = body.car.car
                condition = Cell('#t') if condition.symbol == 'else'
                consequence = body.car.cdr.car
                if condition.eval(env).symbol != '#f'
                    expr = consequence
                else
                    expr = Cell('cond', body.cdr)
            else if expr.pair? and expr.car.special?
                operator = expr.car
                args = expr.cdr
                return Cell(operator.special(args, env))
            else if expr.pair? and expr.car.primitive?
                operator = expr.car
                args = eval_operands(expr.cdr, env)
                return Cell(operator.primitive(args))
            else if expr.pair? and expr.car.procedure?
                operator = expr.car
                args = eval_operands(expr.cdr, env)
                para = operator.procedure.cdr.car
                body = operator.procedure.cdr.cdr.car
                env = Cell(List(para, args), operator.env)
                expr = body
            else if expr.pair?
                expr.car = expr.car.eval env
            else
                throw "eval error: #{expr.write()}"

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
        for name, func of @_specialties
            define(List(name, special: func, name: name), env)
        for name, func of @_primitives
            define(List(name, primitive: func, name: name), env)
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

    @_specialties:
        'quote': (args, env) -> args.car
        'define': (args, env) ->
            args.cdr.car = args.cdr.car.eval(env)
            define(args, env)
        'set!': (args, env) -> set(args, env)
        'env': (args, env) -> env
        'lambda': (args, env) -> procedure: Cell('lambda', args), env: env

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
        else if @primitive? or @special?
            @name
        else if @procedure?
            @procedure.write()
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
