import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const EditorHook = {
  mounted() {
    const get = id => id ? document.getElementById(id) : null

    this.previewEl        = get(this.el.dataset.preview)
    this.exampleDataEl    = get(this.el.dataset.exampleData)
    this.renderBtnEl      = get(this.el.dataset.renderBtn)
    this.toggleDataBtnEl  = get(this.el.dataset.toggleDataBtn)
    this.dataPanelEl      = get(this.el.dataset.dataPanel)
    this.useDataCheckbox  = get(this.el.dataset.useDataCheckbox)

    this.renderedHtml = null
    this.useData = false

    this.cm = window.CodeMirror.fromTextArea(this.el, {
      mode: "htmlmixed",
      lineNumbers: true,
      lineWrapping: true,
      tabSize: 2
    })
    this.cm.setSize(null, "100%")

    const initial = this.cm.getValue()
    if (this.previewEl && initial) this.previewEl.srcdoc = initial

    this.cm.on("change", cm => {
      cm.save()
      if (!this.useData && this.previewEl) this.previewEl.srcdoc = cm.getValue()
    })

    this.toggleDataBtnEl?.addEventListener("click", () => {
      this.dataPanelEl?.classList.toggle("hidden")
    })

    this.useDataCheckbox?.addEventListener("change", () => {
      this.useData = this.useDataCheckbox.checked
      if (!this.previewEl) return
      if (this.useData) {
        this.previewEl.srcdoc = this.renderedHtml ??
          "<p style='color:#aaa;font-family:sans-serif;padding:2rem;text-align:center'>Click Render to preview with data</p>"
      } else {
        this.previewEl.srcdoc = this.cm.getValue()
      }
    })

    this.renderBtnEl?.addEventListener("click", () => {
      this.pushEvent("render_preview", {
        html_body: this.cm.getValue(),
        example_data: this.exampleDataEl?.value || "{}"
      })
    })

    this.handleEvent("preview_rendered", ({html}) => {
      this.renderedHtml = html
      if (this.useDataCheckbox) this.useDataCheckbox.checked = true
      this.useData = true
      if (this.previewEl) this.previewEl.srcdoc = html
    })
  },

  updated() {
    const val = this.el.value
    if (val !== this.cm.getValue()) this.cm.setValue(val)
  },

  destroyed() {
    this.cm?.toTextArea()
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {Editor: EditorHook}
})
liveSocket.connect()
window.liveSocket = liveSocket
