{Cell} = require './little.coffee'


repl = ->
    util = require 'util'
    process.stdin.resume()
    process.stdin.setEncoding 'utf8'
    process.stdout.write 'little> '
    env = Cell.default_env()
    process.stdin.on 'data', (text) ->
        process.stdout.write Cell.read(text.toString()).eval(env).write()
        process.stdout.write '\nlittle> '


repl()
