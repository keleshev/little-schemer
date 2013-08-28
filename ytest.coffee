write = -> process.stdout.write arguments...
print = -> console.log arguments...

success = yes
start = process.hrtime()

red = (s) -> "\x1B[31m#{s}\x1B[0m"
green = (s) -> "\x1B[32m#{s}\x1B[0m"


test = (name, func) ->
    write "#{name}: "
    func()
    write '\n'


test.skip = (name, func) ->
    print "#{name}: skipped"


assert = (cond) ->
    write if cond then '.' else 'F'
    success = no unless cond


assert.equal = (a, b) ->
    if JSON.stringify(a) == JSON.stringify(b)
        write '.'
    else
        success = no
        write 'F\n'
        print 'NOT EQUAL:'
        print a
        print b


assert.raises = (message, func) ->
    try
        func()
        assert false
    catch error
        assert error == message


process.on 'exit', ->
    [seconds, nano] = process.hrtime(start)
    time = seconds + (nano * 1e-9)
    color = if success then green else red
    print color "finished in " + "#{time}"[..4] + " seconds"


module.exports = {test, assert, print}
