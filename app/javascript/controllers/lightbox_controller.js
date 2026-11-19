import { Controller } from "@hotwired/stimulus"

// 写真を押したら画面いっぱいに拡大する。拡大用の <dialog> はレイアウトに 1 つだけ置き、
// 押された写真の URL を差し替えて使い回す（写真の数だけ <dialog> を置くと一覧が重くなるため）
export default class extends Controller {
  static targets = [ "dialog", "image" ]

  open({ params: { src, alt } }) {
    this.imageTarget.src = src
    this.imageTarget.alt = alt
    this.dialogTarget.showModal()
  }

  close() {
    if (!this.dialogTarget.open) return

    this.dialogTarget.close()
  }

  // 次に開いたとき、前の写真が一瞬見えないよう閉じたら消しておく
  clear() {
    this.imageTarget.removeAttribute("src")
    this.imageTarget.alt = ""
  }
}
