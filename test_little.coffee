print = -> console.log arguments...
assert = (cond) -> process.stdout.write if cond then '.' else 'F'
test = (name, func) ->
    process.stdout.write "#{name}: "
    func()
    process.stdout.write '\n'
skip = (mane, func) ->
raises = (message, func) ->
    try
        func()
        assert false
    catch error
        assert error == message


{Cell, List} = require './little'


test 'pair', ->
    assert Cell(1, 2).car.number == 1
    assert Cell(1, 2).cdr.number == 2
    assert Cell(1, 2).write() == '(1 . 2)'
    assert Cell(1, Cell(2, 3)).write() == '(1 2 . 3)'

    assert Cell(1, 2).pair?
    assert not Cell(1, 2).null?
    assert not Cell(1, 2).number?
    assert not Cell(1, 2).symbol?
    assert not Cell(1, 2).atom?


test 'symbol', ->
    assert Cell('hai').symbol == 'hai'
    assert Cell('hai').write() == 'hai'

    assert not Cell('hai').pair?
    assert not Cell('hai').null?
    assert not Cell('hai').number?
    assert Cell('hai').symbol?
    assert Cell('hai').atom?


test 'number', ->
    assert Cell(1).number == 1
    assert Cell('1').number == 1
    assert Cell(1).write() == '1'

    assert not Cell(1).pair?
    assert not Cell(1).null?
    assert Cell(1).number?
    assert not Cell(1).symbol?
    assert Cell(1).atom?


test 'null', ->
    assert Cell(null).null
    assert Cell(null).write() == '()'

    assert not Cell(null).pair?
    assert Cell(null).null?
    assert not Cell(null).number?
    assert not Cell(null).symbol?
    assert not Cell(null).atom?


test 'list', ->
    assert List(1, 2, 3, 4, 5).pair?
    assert List(1, 2, 3, 4, 5).write() == '(1 2 3 4 5)'
    assert List().write() == '()'


test 'is_eq', ->
    assert Cell(null).is_eq Cell(null)
    assert Cell('hai').is_eq Cell('hai')
    assert not Cell('bye').is_eq Cell('hai')

    law = 'eq? takes two non-numeric atoms'
    raises law, ->
        Cell(1, 2).is_eq Cell(1, 2)
    raises law, ->
        Cell(1).is_eq Cell(1)
    raises law, ->
        List(1, 2, 3).is_eq List(1, 2, 3)


test 'read', ->
    assert Cell.read('()')[0].null?
    assert Cell.read('\n(\t ) ')[0].write() == '()'
    assert Cell.read("'()")[0].write() == '(quote ())'
    assert Cell.read('hai')[0].write() == 'hai'
    assert Cell.read('(hai)')[0].write() == '(hai)'
    assert Cell.read('(hai bye)')[0].write() == '(hai bye)'
    assert Cell.read('(hai bye)')[1] == ''
    assert Cell.read("'(hai bye)")[0].write() == '(quote (hai bye))'
    assert Cell.read('(hai . bye)')[0].write() == '(hai . bye)'
    assert Cell.read('(hai . bye)')[0].cdr.write() == 'bye'
    raises 'missing right paren', ->
        Cell.read('(')
    raises 'missing right paren', ->
        Cell.read('(hai ')
    raises 'no delimiter after dot', ->
        Cell.read('(hai .a)')
    assert Cell.read('(define list\n  (lambda l l))')[0].write() == \
                     '(define list (lambda l l))'
    assert Cell.read('1')[0].number == 1


evaluate = (expr, env='()') ->
    Cell.eval(Cell.read(expr)[0], Cell.read(env)[0]).write()


test 'eval', ->
    assert Cell.eval(Cell(1)).write() == '1'
    assert evaluate('1') == '1'
    assert evaluate('#t') == '#t'
    assert evaluate('#f') == '#f'
    assert evaluate("'a") == 'a'
    assert evaluate('(quote (0 #t a))') == '(0 #t a)'
    assert evaluate('a', '( ((a)(1)) )') == '1'
    assert evaluate('b', '( ((a b)(1 2)) )') == '2'
    assert evaluate('b', '( ((a)(1)) ((b)(2)) )') == '2'
    raises 'unbound variable b', ->
        evaluate('b', '( ((a)(1)) )')

test 'environments', ->
    env = Cell.read('((() ()) ((x) (9)))')[0]
    Cell.eval(List('define', 'a', 1), env)
    assert env.write() == '(((a) (1)) ((x) (9)))'

    Cell.eval(List('define', 'a', 2), env)
    assert env.write() == '(((a) (2)) ((x) (9)))'

    Cell.eval(List('set!', 'x', 8), env)
    assert env.write() == '(((a) (2)) ((x) (8)))'


test 'cond', ->
    assert evaluate('(cond (#t 1) (#t 2))') == '1'
    assert evaluate('(cond (#f 1) (#t 2))') == '2'
    assert evaluate('(cond (#f 1) (#f 2) (0 3))') == '3'
    assert evaluate('(cond (#f 1) (#f 2) (else 3))') == '3'


test 'primitives', ->
    env = Cell.default_env()

    assert Cell(->).primitive?
    assert Cell(->).write() == '#<primitive>'

    assert Cell.eval(List('add1', 1), env).number == 2
    assert Cell.eval(List('eq?', '#t', '#t'), env).symbol == '#t'
    assert Cell.eval(Cell.read('(add1 (sub1 5))')[0], env).write() == '5'
    assert Cell.eval(Cell.read('(zero? (sub1 1))')[0], env).write() == '#t'
    assert Cell.eval(Cell.read('(car (cons 0 1))')[0], env).write() == '0'
    assert Cell.eval(Cell.read('(cdr (cons 0 1))')[0], env).write() == '1'
    assert Cell.eval(Cell.read('(number? 1))')[0], env).write() == '#t'
    assert Cell.eval(Cell.read('(number? #t))')[0], env).write() == '#f'


test 'procedures', ->
    proc =
        procedure: Cell.read('(lambda (a) (add1 (add1 a)))')[0]
        env: Cell.default_env()
    assert Cell(proc).procedure?
    assert Cell(proc).write() == '<function (lambda (a) (add1 (add1 a)))>'
    assert Cell.eval(List(List('quote', proc), 1)).write() == '3'


repl = ->
    util = require 'util'
    process.stdin.resume()
    process.stdin.setEncoding 'utf8'
    process.stdout.write 'little> '
    env = Cell.default_env()
    process.stdin.on 'data', (text) ->
        print Cell.eval(Cell.read(text.toString())[0], env).write()
        process.stdout.write 'little> '

repl()
