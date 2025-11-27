const { JSDOM } = require('jsdom')
const fs = require('fs')

const MAX_ATTR_LENGTH = 100
const TARGET_ATTRIBUTES = ['src', 'href', 'data', 'style']
function truncate(el, attrName, value) {
  if (value && MAX_ATTR_LENGTH < value.length) {
    el.setAttribute(attrName, value.substring(0, MAX_ATTR_LENGTH) + '...')
  }
}
function sanitizeDOM() {
  const elements = document.querySelectorAll('*')
  elements.forEach(el => {
    TARGET_ATTRIBUTES.forEach(attrName => {
      if (attrName !== 'data' && el.hasAttribute(attrName)) {
        let value = el.getAttribute(attrName)
        truncate(el, attrName, value)
      } else if (attrName === 'data') {
        const dataAttrs = el.attributes
        for (let i = 0; i < dataAttrs.length; i++) {
          const attr = dataAttrs[i]
          if (attr.name.startsWith('data-')) {
            let value = attr.value
            truncate(el, attr.name, value)
          }
        }
      }
    })
  })
}

function executeJS(code) {
  try {
    window.eval(code)
  } catch (error) {
    console.error(error.message)
  }
}

function saveDOMToFile() {
  sanitizeDOM()
  let bodyHTML = document.body.innerHTML
  bodyHTML = minifyHTML(bodyHTML)
  fs.writeFileSync('dom/dom.html', bodyHTML, 'utf8')
}

function minifyHTML(htmlString) {
  return htmlString
    .replace(/\s+/g, ' ')
    .replace(/> <\//g, '></')
    .replace(/> \</g, '><')
    .trim()
}

const html = fs.readFileSync('src/base.html', 'utf8')
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
})
const window = dom.window
const document = window.document

process.stdin.setEncoding('utf8')
process.stdin.on('data', (data) => {
  const code = data.trim()
  if (code === 'exit') process.exit(0)
  executeJS(code)
  saveDOMToFile()
})