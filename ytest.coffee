write = ->
    process.stdout.write arguments...


print = ->
    console.log arguments...


test = (name, func) ->
    write "#{name}: "
    func()
    write '\n'


test.skip = (name, func) ->
    print "#{name}: skipped"


assert = (cond) ->
    write if cond then '.' else 'F'


assert.equal = (a, b) ->
    if JSON.stringify(a) == JSON.stringify(b)
        write '.'
    else
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


module.exports = {test, assert}
