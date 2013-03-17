editor = CodeMirror.fromTextArea document.getElementById('code'),
    lineNumbers: false,
    mode: 'scheme',
    keyMap: if location.hash is '#vi' then 'vim' else 'default',
    lineWrapping: true,
    autofocus: true,
    showCursorWhenSelecting: true
    matchBrackets: true

elements = []
run = (editor) ->
    results = little.eval editor.getValue().trimRight()
    results.forEach ({line, result}) ->
        element = document.createElement 'span'
        color = if result.match /^error/ then 'brown' else 'green'
        element.style.color = color
        element.style.textShadow="0px 0px 60px #{color}"
        element.innerText = result
        element.innerHTML = '&nbsp;&rArr; ' + element.innerHTML
        editor.addWidget {line: line, ch: 1000}, element
        elements.push element

CodeMirror.keyMap.default['Shift-Enter'] = run
CodeMirror.keyMap.vim['Shift-Enter'] = run

editor.on 'change', (editor, change) ->
    elements.forEach (element) ->
        element.style.left = '-100000px'
    run(editor)

run(editor)

window.app = {run, editor}
