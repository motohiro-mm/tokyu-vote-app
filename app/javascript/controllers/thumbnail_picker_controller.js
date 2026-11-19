import { Controller } from "@hotwired/stimulus"

// 選んだ画像を並べ、投票一覧のサムネにする 1 枚を選ばせる。
// 並べ替え自体はサーバーが thumbnail_index を見て行うので、ここでは選択肢を出すだけ
export default class extends Controller {
  static targets = ["input", "fieldset", "options", "template"]

  disconnect() {
    this.revokePreviews()
  }

  render() {
    this.revokePreviews()
    this.optionsTarget.replaceChildren()

    const files = Array.from(this.inputTarget.files)
    // 1 枚なら選ぶ余地がないので出さない
    this.fieldsetTarget.hidden = files.length < 2
    if (files.length < 2) return

    files.forEach((file, index) => {
      const option = this.templateTarget.content.firstElementChild.cloneNode(true)
      const radio = option.querySelector("input")
      radio.value = index
      radio.checked = index === 0

      const url = URL.createObjectURL(file)
      this.previewUrls.push(url)
      const image = option.querySelector("img")
      // HEIC は表示できないブラウザが多いので、読めなければファイル名だけにする
      image.addEventListener("error", () => image.remove(), { once: true })
      image.src = url
      option.querySelector("[data-name]").textContent = file.name

      this.optionsTarget.append(option)
    })
  }

  revokePreviews() {
    this.previewUrls?.forEach((url) => URL.revokeObjectURL(url))
    this.previewUrls = []
  }
}
