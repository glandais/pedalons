// The app's side of the bridge, faked in a desktop browser (see serve.mjs). Classic script, loaded
// before planner.js. Every message of the page is logged in the console; `done` and `close` are
// also shown on the page, since they are what the app's form would receive.
;(function () {
  const params = new URLSearchParams(location.search)
  const inFlight = new Map()
  const planner = () => window.pedalonsPlanner

  function show(message) {
    let panel = document.getElementById('harness-panel')
    if (!panel) {
      panel = document.createElement('pre')
      panel.id = 'harness-panel'
      panel.style.cssText =
        'position:fixed;inset:10% 5%;z-index:9999;overflow:auto;margin:0;padding:12px;' +
        'background:#111;color:#eee;font:12px/1.4 monospace;white-space:pre-wrap;word-break:break-all'
      panel.title = 'click to dismiss'
      panel.onclick = () => panel.remove()
      document.body.appendChild(panel)
    }
    panel.textContent = JSON.stringify(message, null, 2)
  }

  const handlers = {
    async ready() {
      const load = await (await fetch('/__load')).json()
      for (const key of ['theme', 'locale', 'units', 'routeName', 'teamSlug']) {
        if (params.has(key)) load[key] = params.get(key)
      }
      planner().load(load)
    },
    async request(message) {
      const controller = new AbortController()
      inFlight.set(message.id, controller)
      try {
        const answer = await fetch('/__request', {
          method: 'POST',
          body: JSON.stringify(message),
          signal: controller.signal,
        })
        planner().response({ id: message.id, ...(await answer.json()) })
      } catch {
        if (!controller.signal.aborted) planner().response({ id: message.id, status: 0 })
      } finally {
        inFlight.delete(message.id)
      }
    },
    cancel(message) {
      inFlight.get(message.id)?.abort()
    },
    pickGpx() {
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = '.gpx'
      input.oncancel = () => planner().gpx(null)
      input.onchange = () => {
        const file = input.files[0]
        const reader = new FileReader()
        reader.onload = () => {
          const url = String(reader.result)
          planner().gpx({ name: file.name, base64: url.slice(url.indexOf(',') + 1) })
        }
        reader.readAsDataURL(file)
      }
      input.click()
    },
    locate() {
      navigator.geolocation.getCurrentPosition(
        (found) => planner().position({ lng: found.coords.longitude, lat: found.coords.latitude }),
        () => planner().position(null)
      )
    },
    done: show,
    close: show,
    quotaRefused: show,
    error: show,
  }

  window.PedalonsBridge = {
    postMessage(json) {
      const message = JSON.parse(json)
      console.info('[bridge] page →', message)
      handlers[message.type]?.(message)
    },
  }
})()
