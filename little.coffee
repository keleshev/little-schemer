print = -> console.log arguments...


DELIMITER = /(\s|\))/


count_newlines = (source) ->
    newlines = source.match /\n/g
    newlines = [] if not newlines?
    return newlines.length


optimize = (name, value) ->
    if name == '+' and value.procedure?
        extended = env[..]
        extended.push({'+': value})
        value.env = extended
        if Cell.read('(+ 10 20)').eval(extended).write() == '30'
            value.primitive = (args) ->
                Cell(args.car.number + args.cdr.car.number)
        else
            value.env = env
    value


define = (args, env) ->
    name = args.car.symbol
    value = args.cdr.car
    value = optimize(name, value)
    env[env.length - 1][name] = value
    return 'ok'


lookup = (exp, env) ->
    for _, frame of env
        for name, value of frame
            return value if name == exp.symbol
    for name, value of Cell.default_env()[0]
        return value if name == exp.symbol
    throw "unbound variable #{exp.write()}"


frame = (para, args) ->
    fr = {}
    while not para.null?
        fr[para.car.symbol] = args.car
        [para, args] = [para.cdr, args.cdr]
    fr


class Cell

    constructor: (args...) ->
        if args.length == 2
            [car, cdr] = args
            throw "undefined: #{car}, #{cdr}" if not car? or not cdr?
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
        else if args[0].primitive? and args[0].procedure?
            @primitive = args[0].primitive
            @procedure = args[0].procedure
            @env = args[0].env
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
            throw "Cell fail: #{args[0]}"
        @cell = true
        return new Cell arguments... if this not instanceof Cell

    @_read_pair: (source) ->
        source = source.trim()
        if source[0] == ')'
            return [Cell(null), source[1..]]
        [car, rest] = @_read(source)
        rest = rest.trim()
        throw 'missing ")"' if rest == ''
        if rest[0] == '.'
            throw 'missing ")"' if rest[1..] == ''
            throw 'no delimiter after dot' if not DELIMITER.test rest[1]
            [cdr, rest] = @_read(rest[1..])
            throw 'missing ")"' if rest[0] != ')'
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

    _eval: (env) ->
        exp = this
        if exp.self_evaluating?
            return exp
        else if exp.symbol?
            return lookup(exp, env)
        else if exp.pair? and exp.car.special?
            operator = exp.car
            args = exp.cdr
            return Cell(operator.special(args, env))
        else if exp.pair? and exp.car.primitive?
            operator = exp.car
            args = exp.cdr
            return Cell(operator.primitive(args))
        else if exp.null?  # should it be self evaluating?!
            return exp
        else
            throw "_eval error: #{this.write()}"

    copy: ->
        throw 'copy works only on pairs' if not @car? or not @cdr? or not @pair?
        Cell(@car, @cdr)

    eval: (env=[]) ->
        exp = Cell(this, Cell(null))
        stack = [{exp: Cell(exp, Cell(null)), env: env},
                 {exp: exp, env: env}]
        counter = 0
        loop
            me = stack[stack.length - 1]
            parent = stack[stack.length - 2]
            throw 'not parent?' if not parent?
            counter += 1
            throw 'too much recursion' if counter > 20000

            if me.exp.car.pair?
                car = me.exp.car.copy()
                me.exp.car = car
                stack.push exp: car, env: me.env
            else if me.exp.car.special == Cell._specialties['cond']
                throw '(cond) with no body' if me.exp.cdr.null?
                stack.pop()
                condition = me.exp.cdr.car.car
                condition = Cell('#t') if condition.symbol == 'else'
                consequence = me.exp.cdr.car.cdr.car
                if condition.eval(me.env).symbol != '#f'  # condition is true
                    if consequence.pair?
                        parent.exp.car = consequence.copy()
                        stack.push exp: parent.exp.car, env: me.env
                    else
                        parent.exp.car = consequence._eval me.env
                else
                    parent.exp.car = Cell('cond', me.exp.cdr.cdr)
                    stack.push exp: parent.exp.car, env: me.env
            else if me.exp.car.special? or me.exp.car.primitive?
                throw 'builtin not in head position' if parent.exp.car != me.exp
                stack.pop()
                parent.exp.car = me.exp._eval me.env
                if parent.exp.cdr.null?
                    # cannot continue right, restart
                    grandpa = stack[stack.length - 2]
                    throw 'parent 2' if not grandpa?
                    parent.exp = grandpa.exp.car  # reset to parent's head
                else  # continue right
                    cdr = parent.exp.cdr.copy()
                    parent.exp.cdr = cdr
                    parent.exp = cdr
            else if me.exp.car.procedure?
                throw 'proc not in head position' if parent.exp.car != me.exp
                stack.pop()
                operator = me.exp.car
                args = me.exp.cdr
                para = operator.procedure.cdr.car
                body = operator.procedure.cdr.cdr.car.copy()
                parent.exp.car = body
                new_env = operator.env.concat frame(para, args)
                #stack.push exp: body, env: Cell(List(para, args), operator.env)
                stack.push exp: body, env: new_env
            else  # me.exp.car is not pair/special/primitive/procedure
                me.exp.car = me.exp.car._eval me.env
                # if not special or not in head position
                if not me.exp.car.special? or parent.exp.car != me.exp
                    if me.exp.cdr.null?
                        # cannot continue right, restart
                        me.exp = parent.exp.car
                    else  # continue right
                        cdr = me.exp.cdr.copy()
                        me.exp.cdr = cdr
                        me.exp = cdr

            if stack.length is 2
                me = stack[stack.length - 1]
                return me.exp.car

    @evaluate: (source) ->
        env = Cell.default_env()
        results = []
        line = 0
        while source != ''
            try
                [parsed, rest] = Cell._read(source)
            catch error
                line += count_newlines source
                results.push line: line, result: "error: #{error}"
                break
            line += count_newlines source.replace(rest, '')
            source = rest
            try
                result = parsed.eval(env).write()
            catch error
                results.push line: line, result: "error: #{error}"
                break
            results.push line: line, result: result
        return results

    @default_env: ->
        env = [{}]
        for name, func of @_specialties
            env[0][name] = special: func, name: name
        for name, func of @_primitives
            env[0][name] = primitive: func, name: name
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
        'env': (args, env) -> env
        'lambda': (args, env) -> procedure: Cell('lambda', args), env: env
        'cond': (args, env) -> throw 'placeholder; should not be called'

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
        else if @procedure?
            '#' + @procedure.write()
        else if @primitive? or @special?
            '#' + @name
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


provide = {Cell, List, eval: Cell.evaluate}
module?.exports = provide
window?.little = provide
