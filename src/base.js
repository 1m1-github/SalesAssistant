document.head.insertAdjacentHTML('beforeend', '<link rel="stylesheet" href="futurism-theme.css">')
const eventSource = new EventSource('/events')
eventSource.onmessage = function (event) {
    eval(event.data)
}
